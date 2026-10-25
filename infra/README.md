# CutTracker AWS backend

One CDK stack (`ap-south-1`): DynamoDB single table, API Lambda behind an HTTP API, AI proxy Lambda
behind a Function URL, and an S3 + CloudFront bucket for public assets (exercise clips).

Nothing here has been deployed. Do the steps in order when you're ready.

## 1. Google OAuth (once)

In Google Cloud Console, create a project, configure the OAuth consent screen, then create:

- a **Web** client ID with authorized JavaScript origins `https://tsrnb.github.io` and `http://localhost:8080`
- an **Android** client ID (package name + SHA-1 of your signing key)

The backend accepts ID tokens whose audience is any of the IDs you pass at deploy time.

## 2. Secrets (once per stage)

SecureString parameters can't be created by CloudFormation:

```bash
aws ssm put-parameter --region ap-south-1 --type SecureString \
  --name /cuttracker/dev/jwt-secret --value "$(openssl rand -hex 32)"
aws ssm put-parameter --region ap-south-1 --type SecureString \
  --name /cuttracker/dev/openai-key --value "<paste-your-real-openai-key>" --overwrite
```

## 3. Deploy

```bash
cd infra && npm install
npx cdk bootstrap            # first time in the account/region
npx cdk deploy -c stage=dev -c googleClientIds=<web-id>,<android-id> -c alarmEmail=you@example.com
```

Outputs: `ApiUrl`, `ChatUrl`, `CdnUrl`, `AssetsBucket`.

## 4. Upload the exercise clips

```bash
./scripts/upload-assets.sh <AssetsBucket> <CdnUrl>
```

## 5. Point the app at it

Fill `flutter_app/secrets.json` (see `secrets.example.json`) with `API_URL`, `AI_URL`, `CDN_URL`,
`GOOGLE_WEB_CLIENT_ID`, then build with `--dart-define-from-file=secrets.json`.

## Cost notes

Everything is pay-per-use (DynamoDB on-demand, Lambda arm64, HTTP API, CloudFront). No NAT, VPC, WAF or
Secrets Manager. The AI proxy enforces a per-user daily limit (`DAILY_AI_LIMIT`, default 150 calls).
