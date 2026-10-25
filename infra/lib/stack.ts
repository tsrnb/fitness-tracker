import * as path from 'node:path';
import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as apigw from 'aws-cdk-lib/aws-apigatewayv2';
import { HttpLambdaIntegration } from 'aws-cdk-lib/aws-apigatewayv2-integrations';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as cw from 'aws-cdk-lib/aws-cloudwatch';
import * as cwActions from 'aws-cdk-lib/aws-cloudwatch-actions';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as subs from 'aws-cdk-lib/aws-sns-subscriptions';
import * as ssm from 'aws-cdk-lib/aws-ssm';

export interface CutTrackerProps extends cdk.StackProps {
  stage: 'dev' | 'prod';
  googleClientIds: string[];
  allowedOrigins: string[];
  alarmEmail?: string;
}

export class CutTrackerStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: CutTrackerProps) {
    super(scope, id, props);
    const prod = props.stage === 'prod';
    const removal = prod ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY;

    // ---- data ----
    const table = new dynamodb.Table(this, 'Table', {
      partitionKey: { name: 'pk', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'sk', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'ttl',
      pointInTimeRecoverySpecification: { pointInTimeRecoveryEnabled: prod },
      removalPolicy: removal,
    });

    // Created once by hand (see infra/README.md): SecureString parameters
    // can't be created by CloudFormation.
    const jwtParam = `/cuttracker/${props.stage}/jwt-secret`;
    const openaiParam = `/cuttracker/${props.stage}/openai-key`;
    const secretArn = (name: string) => cdk.Stack.of(this).formatArn({ service: 'ssm', resource: 'parameter', resourceName: name.slice(1) });

    const fnDefaults = {
      runtime: lambda.Runtime.NODEJS_24_X,
      architecture: lambda.Architecture.ARM_64,
      bundling: { minify: true, sourceMap: false, externalModules: ['@aws-sdk/*'] },
      logRetention: logs.RetentionDays.ONE_MONTH,
    };

    // ---- API ----
    const apiFn = new NodejsFunction(this, 'ApiFn', {
      ...fnDefaults,
      entry: path.join(__dirname, '../lambda/api.ts'),
      memorySize: 256,
      timeout: cdk.Duration.seconds(15),
      environment: { TABLE: table.tableName, JWT_PARAM: jwtParam, GOOGLE_CLIENT_IDS: props.googleClientIds.join(',') },
    });
    table.grantReadWriteData(apiFn);
    apiFn.addToRolePolicy(new cdk.aws_iam.PolicyStatement({ actions: ['ssm:GetParameter'], resources: [secretArn(jwtParam)] }));

    const httpApi = new apigw.HttpApi(this, 'Api', {
      corsPreflight: {
        allowOrigins: props.allowedOrigins,
        allowMethods: [apigw.CorsHttpMethod.ANY],
        allowHeaders: ['Content-Type', 'Authorization'],
        maxAge: cdk.Duration.hours(1),
      },
    });
    // Not ANY: that would also route OPTIONS to the Lambda, and API Gateway only answers CORS preflights itself when no route matches OPTIONS.
    httpApi.addRoutes({
      path: '/{proxy+}',
      methods: [apigw.HttpMethod.GET, apigw.HttpMethod.POST, apigw.HttpMethod.PUT, apigw.HttpMethod.PATCH, apigw.HttpMethod.DELETE],
      integration: new HttpLambdaIntegration('ApiInt', apiFn) });
    const stage = httpApi.defaultStage!.node.defaultChild as apigw.CfnStage;
    stage.defaultRouteSettings = { throttlingBurstLimit: 100, throttlingRateLimit: 50 };

    // ---- AI proxy (Function URL: no 30 s cap) ----
    const chatFn = new NodejsFunction(this, 'ChatFn', {
      ...fnDefaults,
      entry: path.join(__dirname, '../lambda/chat.ts'),
      memorySize: 256,
      timeout: cdk.Duration.seconds(60),
      environment: { TABLE: table.tableName, JWT_PARAM: jwtParam, OPENAI_PARAM: openaiParam, DAILY_AI_LIMIT: '150' },
    });
    table.grantReadWriteData(chatFn);
    chatFn.addToRolePolicy(new cdk.aws_iam.PolicyStatement({ actions: ['ssm:GetParameter'], resources: [secretArn(jwtParam), secretArn(openaiParam)] }));
    const chatUrl = chatFn.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE, // the function verifies the session JWT itself
      cors: { allowedOrigins: props.allowedOrigins, allowedMethods: [lambda.HttpMethod.GET, lambda.HttpMethod.POST], allowedHeaders: ['Content-Type', 'Authorization'] },
    });

    // ---- public assets (exercise clips etc.): private bucket, public via CloudFront ----
    const assets = new s3.Bucket(this, 'Assets', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      removalPolicy: removal,
      autoDeleteObjects: !prod,
    });
    const cdn = new cloudfront.Distribution(this, 'Cdn', {
      priceClass: cloudfront.PriceClass.PRICE_CLASS_200, // includes India
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(assets),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
        originRequestPolicy: cloudfront.OriginRequestPolicy.CORS_S3_ORIGIN,
        responseHeadersPolicy: cloudfront.ResponseHeadersPolicy.CORS_ALLOW_ALL_ORIGINS,
        compress: true,
      },
    });

    // ---- alarms ----
    const topic = new sns.Topic(this, 'Alarms');
    if (props.alarmEmail) topic.addSubscription(new subs.EmailSubscription(props.alarmEmail));
    for (const [name, fn] of [['Api', apiFn], ['Chat', chatFn]] as const) {
      new cw.Alarm(this, `${name}Errors`, {
        metric: fn.metricErrors({ period: cdk.Duration.minutes(5) }),
        threshold: 5,
        evaluationPeriods: 1,
        treatMissingData: cw.TreatMissingData.NOT_BREACHING,
      }).addAlarmAction(new cwActions.SnsAction(topic));
    }
    new cw.Alarm(this, 'TableThrottles', {
      metric: table.metricThrottledRequestsForOperations({ operations: [dynamodb.Operation.PUT_ITEM, dynamodb.Operation.QUERY], period: cdk.Duration.minutes(5) }),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cw.TreatMissingData.NOT_BREACHING,
    }).addAlarmAction(new cwActions.SnsAction(topic));

    new cdk.CfnOutput(this, 'ApiUrl', { value: httpApi.apiEndpoint });
    new cdk.CfnOutput(this, 'ChatUrl', { value: chatUrl.url });
    new cdk.CfnOutput(this, 'CdnUrl', { value: `https://${cdn.distributionDomainName}` });
    new cdk.CfnOutput(this, 'AssetsBucket', { value: assets.bucketName });
  }
}
