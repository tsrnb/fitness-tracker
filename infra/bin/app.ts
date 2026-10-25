#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { CutTrackerStack } from '../lib/stack';

const app = new cdk.App();
const stage = (app.node.tryGetContext('stage') ?? 'dev') as 'dev' | 'prod';
const googleClientIds = String(app.node.tryGetContext('googleClientIds') ?? '').split(',').filter(Boolean);
if (googleClientIds.length === 0) {
  throw new Error('Pass the Google OAuth client IDs: cdk deploy -c googleClientIds=<web-id>,<android-id>');
}

new CutTrackerStack(app, `CutTracker-${stage}`, {
  stage,
  googleClientIds,
  allowedOrigins: ['https://tsrnb.github.io', ...(stage === 'dev' ? ['http://localhost:8080'] : [])],
  alarmEmail: app.node.tryGetContext('alarmEmail'),
  env: { region: 'ap-south-1', account: process.env.CDK_DEFAULT_ACCOUNT },
});
