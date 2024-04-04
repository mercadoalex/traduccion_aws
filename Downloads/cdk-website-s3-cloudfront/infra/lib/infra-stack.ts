import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Bucket, BlockPublicAccess, BucketEncryption } from 'aws-cdk-lib/aws-s3';
import { OriginAccessIdentity } from 'aws-cdk-lib/aws-cloudfront';
import { Distribution } from 'aws-cdk-lib/aws-cloudfront';
import { ViewerProtocolPolicy, AllowedMethods } from 'aws-cdk-lib/aws-cloudfront';
import * as s3deploy from "aws-cdk-lib/aws-s3-deployment";

// import * as sqs from 'aws-cdk-lib/aws-sqs';

export class InfraEstaticStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    //Definimos la configuración del bucket S3
    const s3Bucket = new Bucket(this, 'storage',{
      websiteIndexDocument: 'index.html',
      websiteErrorDocument: 'index.html',
      blockPublicAccess: BlockPublicAccess.BLOCK_ACLS,
      encryption: BucketEncryption.S3_MANAGED,
      enforceSSL: false,
      publicReadAccess: true,
      autoDeleteObjects: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY
    });
  
    //Creamos una identidad de origen y se lo asignamos al bucket s3
    const oia = new OriginAccessIdentity(this, 'OIA', {
      comment: "OIA for Images infra"
    });
    s3Bucket.grantRead(oia);
    
    
    /* Definimos la configuració de nuestro bucket s3 */
    const cloudfrontDistrubution = new Distribution( this, 'spo-public-cf_', {
      defaultBehavior: {
        origin: new cdk.aws_cloudfront_origins.S3Origin(s3Bucket), //apuntamos nuestro cloud front a nuestro bucket
        viewerProtocolPolicy: ViewerProtocolPolicy.ALLOW_ALL,
        allowedMethods: AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
      },
      priceClass: cdk.aws_cloudfront.PriceClass.PRICE_CLASS_100,
      
    })
  
    //Iniciamos un despliegue de los archivos que están en la carpeta public a la raiz de nuestro bucket
    new s3deploy.BucketDeployment( this, 'DeployFiles', { 
      sources: [ s3deploy.Source.asset('../public/')],
      destinationBucket: s3Bucket,
    })
  
    //Imprimimos la url de nuestra distribución de cloud front
    new cdk.CfnOutput(this, "ulr", {
      value: `${cloudfrontDistrubution.distributionDomainName}`
    })



  }
}
