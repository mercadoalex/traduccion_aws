# Configure the AWS provider
provider "aws" {
  region = "us-east-1" # Specify the AWS region
}

# Create an S3 bucket for English content
resource "aws_s3_bucket" "english-bucket" {
  bucket        = var.en_bucket_name # Use the bucket name from variables
  force_destroy = true               # Allow Terraform to delete the bucket and its contents

}

# Create an S3 bucket for Spanish content
resource "aws_s3_bucket" "spanish-bucket" {
  bucket        = var.es_bucket_name # Use the bucket name from variables
  force_destroy = true               # Allow Terraform to delete the bucket and its contents

}

# Upload HTML file to the English bucket
resource "aws_s3_object" "en_html_upload" {
  bucket       = aws_s3_bucket.english-bucket.bucket # Reference the English bucket
  key          = "index.html"                        # Specify the object key with the correct path
  source       = "backup/index.html"                 # Path to the source file
  content_type = "text/html"                         # Set the content type
}

# Upload CSS file to the English bucket
resource "aws_s3_object" "en_css_upload" {
  bucket       = aws_s3_bucket.english-bucket.bucket # Reference the English bucket
  key          = "index.css"                         # Specify the object key with the correct path
  source       = "backup/index.css"                  # Path to the source file
  content_type = "text/css"                          # Set the content type
}

# Upload HTML file to the Spanish bucket
resource "aws_s3_object" "es_html_upload" {
  bucket       = aws_s3_bucket.spanish-bucket.bucket # Reference the Spanish bucket
  key          = "index.html"                        # Specify the object key with the correct path
  source       = "backup/index.html"                 # Path to the source file
  content_type = "text/html"                         # Set the content type
}

# Upload CSS file to the Spanish bucket
resource "aws_s3_object" "es_css_upload" {
  bucket       = aws_s3_bucket.spanish-bucket.bucket # Reference the Spanish bucket
  key          = "index.css"                         # Specify the object key with the correct path
  source       = "backup/index.css"                  # Path to the source file
  content_type = "text/css"                          # Set the content type
}
#AWS CloudFront Origin Access Control (OAC) resource
#The OAC is used to control access to the origin, in this case, an S3 bucket, ensuring that only CloudFront can access the S3 bucket.
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-cloudfront-oac"
  description                       = "Access to S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
#locals block is used to define local variables within a configuration
locals {
  s3_origin_id = "myS3Origin"
}
#AWS CloudFront distribution resource that uses an S3 bucket as its origin
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.english-bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  default_root_object = "index.html"
  #defines the default cache behavior for a CloudFront distribution, the default path pattern (typically /*). 
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    # how CloudFront handles query strings, headers, and cookies
    forwarded_values {
      query_string = false
      headers      = ["Accept-Language"]

      cookies {
        forward = "none" # CloudFront does not forward cookies to the origin.
      }
    }
    # this block associates an AWS Lambda function with a specific CloudFront event type
    lambda_function_association {
      event_type = "origin-request"
      lambda_arn = aws_lambda_function.terraform_lambda_func.qualified_arn
    }
    # configures the caching behavior and protocol policy for a CloudFront distribution.
    viewer_protocol_policy = "allow-all" #both HTTP and HTTPS requests are allowed.
    min_ttl                = 0           #0 means that CloudFront will always check with the origin for the latest version of the object
    default_ttl            = 1           #value of 1 second means that objects are cached for only 1 second by default
    max_ttl                = 1           #value of 1 second means that objects are cached for a maximum of 1 second
  }

  price_class = "PriceClass_100"
  # means that the distribution will use only the least expensive AWS edge locations.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  # specifies the SSL/TLS certificate that CloudFront uses to secure connections with viewers
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
#  defines a resource for attaching a bucket policy to an S3 bucket
resource "aws_s3_bucket_policy" "english-policy" {
  bucket = aws_s3_bucket.english-bucket.id
  policy = data.aws_iam_policy_document.cloudfront_oac_access_english.json
}
# defines an IAM policy document that grants CloudFront access to objects in an S3 bucket
data "aws_iam_policy_document" "cloudfront_oac_access_english" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.english-bucket.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}
# defines a resource for attaching a bucket policy to an S3 bucket
resource "aws_s3_bucket_policy" "spanish-policy" {
  bucket = aws_s3_bucket.spanish-bucket.id
  policy = data.aws_iam_policy_document.cloudfront_oac_access_spanish.json
}
# defines an IAM policy document that grants CloudFront access to objects in an S3 bucket
data "aws_iam_policy_document" "cloudfront_oac_access_spanish" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.spanish-bucket.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}
#AWS IAM role that can be assumed by AWS Lambda functions, including those deployed at the edge (Lambda@Edge)
resource "aws_iam_role" "lambda_role" {
  name               = "Detection_Lambda_Function_Role"
  assume_role_policy = <<EOF
    {
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Principal": {
        "Service": ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
        },
        "Effect": "Allow",
        "Sid": ""
    }
    ]
    }
    EOF
}
#AWS IAM policy resource that grants specific permissions to a Lambda function
resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for lambda role"
  policy      = <<EOF
    {
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*",
        "Effect": "Allow"
    }
    ]
    }
    EOF
}

# Attach IAM policy to IAM role
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name            # Reference the IAM role
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn # Reference the IAM policy
}

# Define the IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow",
        Principal = {
          Service = "edgelambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Define the IAM policy for Lambda to access the S3 bucket
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda_s3_policy"
  description = "IAM policy for Lambda to access S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::my-spanish-assets-bucket",
          "arn:aws:s3:::my-spanish-assets-bucket/*"
        ]
      }
    ]
  })
}

# Attach the IAM policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

# Create a zip archive of the Lambda function code
data "archive_file" "zip_the_python_code" {
  type        = "zip"                              # Specify the archive type
  source_file = "${path.module}/lambda/lambda.py"  # Path to the source file
  output_path = "${path.module}/lambda/lambda.zip" # Path to the output zip file
}

# Create the Lambda function
resource "aws_lambda_function" "terraform_lambda_func" {
  filename      = "${path.module}/lambda/lambda.zip"                             # Path to the zip file
  function_name = "origin-function"                                              # Name of the Lambda function
  role          = aws_iam_role.lambda_execution_role.arn                         # ARN of the IAM role
  handler       = "lambda.handler"                                               # Handler function
  runtime       = "python3.12"                                                   # Runtime environment
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role] # Ensure IAM policy is attached before creating the function
  publish       = true                                                           # Publish the Lambda function
}