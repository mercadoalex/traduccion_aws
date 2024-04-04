#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { InfraEstaticStack } from '../lib/infra-stack';

const app = new cdk.App();
new InfraEstaticStack(app, 'InfraEstaticStack', {
  env: {
    region: 'us-east-1', //Region en donde se va a desplegar tu proyecto
    account: '' //Tu número de cuenta de AWS
  }
});