# Traducción AWS

## Overview

This project sets up a multi-language content delivery infrastructure using AWS services. The infrastructure includes S3 buckets for storing English and Spanish content, CloudFront for content delivery, and Lambda functions for dynamic request handling. The project is managed using Terraform, which automates the provisioning and configuration of the AWS resources.

## Project Structure

- **infrastructure.tf**: Defines the AWS infrastructure, including S3 buckets, CloudFront distribution, IAM policies, and Lambda functions.
- **dev.tfvars**: Contains variable definitions for the development environment.
- **buildspec.yml**: Specifies the build process for AWS CodeBuild.
- **lambda.py**: Contains the Lambda function code for handling CloudFront requests.
- **cicd.tf**: Defines the CI/CD pipeline using AWS CodePipeline and CodeBuild.

## Prerequisites

- Terraform installed
- AWS CLI configured with appropriate permissions
- Git installed

## Setup Instructions

1. **Clone the Repository**:
   ```sh
   git clone https://github.com/mercadoalex/traduccion_aws.git
   cd traduccion_aws