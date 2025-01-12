# Create a CodeStar connection to GitHub
resource "aws_codestarconnections_connection" "codestar_connection" {
  name          = "app-dev-codestar" # Name of the CodeStar connection
  provider_type = "GitHub"           # Type of provider (GitHub in this case)
}

# IAM role for CodePipeline with necessary permissions to use CodeStar connection
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM policy for CodePipeline to use CodeStar connection and other necessary permissions
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codestar-connections:UseConnection",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
}

# Create a CodeBuild project
resource "aws_codebuild_project" "codebuild_project" {
  name          = "codebuild-project"
  description   = "CodeBuild project for building the application"
  build_timeout = "5" # Build timeout in minutes

  # Define the source for the CodeBuild project
  source {
    type      = "CODEPIPELINE"  # Use CodePipeline as the source
    buildspec = "buildspec.yml" # Path to the buildspec file
  }

  # Define the environment for the CodeBuild project
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL" # Compute type for the build environment
    image                       = "aws/codebuild/standard:4.0" # Docker image for the build environment
    type                        = "LINUX_CONTAINER" # Type of build environment
    privileged_mode             = true # Enable privileged mode for the build environment
    environment_variable {
      name  = "ENV_VAR"
      value = "value"
    }
  }

  # Define the artifacts for the CodeBuild project
  artifacts {
    type = "CODEPIPELINE" # Use CodePipeline for artifacts
  }

  # Define the service role for the CodeBuild project
  service_role = aws_iam_role.codebuild_service_role.arn # ARN of the IAM role for CodeBuild
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_service_role" {
  name = "codebuild_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM policy for CodeBuild with S3 permissions
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild_policy"
  role = aws_iam_role.codebuild_service_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion"
        ],
        Resource = [
          "arn:aws:s3:::my-english-assets-bucket",
          "arn:aws:s3:::my-english-assets-bucket/*",
          "arn:aws:s3:::my-spanish-assets-bucket",
          "arn:aws:s3:::my-spanish-assets-bucket/*",
          "arn:aws:s3:::my-codepipeline-us-east-1-bucket1",
          "arn:aws:s3:::my-codepipeline-us-east-1-bucket1/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Create a CodePipeline
resource "aws_codepipeline" "codepipeline" {
  name     = "tf-test-pipeline"                 # Name of the CodePipeline
  role_arn = aws_iam_role.codepipeline_role.arn # ARN of the IAM role for CodePipeline

  # Define the artifact store for the pipeline
  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket # S3 bucket for storing artifacts
    type     = "S3"                                     # Type of artifact store (S3 in this case)
  }

  # Define the Source stage
  stage {
    name = "Source" # Name of the stage

    action {
      name             = "Source"                   # Name of the action
      category         = "Source"                   # Category of the action (Source in this case)
      owner            = "AWS"                      # Owner of the action (AWS in this case)
      provider         = "CodeStarSourceConnection" # Provider of the action (CodeStarSourceConnection in this case)
      version          = "1"                        # Version of the action
      output_artifacts = ["source_output"]          # Output artifacts from the action

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.codestar_connection.arn # ARN of the CodeStar connection
        FullRepositoryId = var.github_repository_url                                  # Full repository ID (GitHub repository URL)
        BranchName       = "main"                                                     # Branch name to use (main in this case)
      }
    }
  }

  # Define the Build stage
  stage {
    name = "Build" # Name of the stage

    action {
      name             = "Build"                   # Name of the action
      category         = "Build"                   # Category of the action (Build in this case)
      owner            = "AWS"                     # Owner of the action (AWS in this case)
      provider         = "CodeBuild"               # Provider of the action (CodeBuild in this case)
      version          = "1"                       # Version of the action
      input_artifacts  = ["source_output"]         # Input artifacts for the action
      output_artifacts = ["build_output"]          # Output artifacts from the action

      configuration = {
        ProjectName = aws_codebuild_project.codebuild_project.name # Name of the CodeBuild project
      }
    }
  }

  # Additional stages (e.g., Deploy) can be defined here
}

# Create an S3 bucket for CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = var.codepipeline_bucket_name
  force_destroy = true # Allow Terraform to delete the bucket and its contents
}

# IAM policy document for CodePipeline
data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.codepipeline_bucket.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.codepipeline_bucket.bucket}/*"
    ]
  }
}

# Attach the policy to the S3 bucket
resource "aws_s3_bucket_policy" "codepipeline_bucket_policy" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

# Attach the policy to the English assets bucket
resource "aws_s3_bucket_policy" "english_assets_bucket_policy" {
  bucket = "my-english-assets-bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::<account-id>:role/codebuild_service_role"
        },
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion"
        ],
        Resource = [
          "arn:aws:s3:::my-english-assets-bucket",
          "arn:aws:s3:::my-english-assets-bucket/*"
        ]
      }
    ]
  })
}

# Attach the policy to the Spanish assets bucket
resource "aws_s3_bucket_policy" "spanish_assets_bucket_policy" {
  bucket = "my-spanish-assets-bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::<account-id>:role/codebuild_service_role"
        },
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion"
        ],
        Resource = [
          "arn:aws:s3:::my-spanish-assets-bucket",
          "arn:aws:s3:::my-spanish-assets-bucket/*"
        ]
      }
    ]
  })
}

# Attach the policy to the CodePipeline artifacts bucket
resource "aws_s3_bucket_policy" "codepipeline_artifacts_bucket_policy" {
  bucket = "my-codepipeline-us-east-1-bucket1"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::<account-id>:role/codebuild_service_role"
        },
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion"
        ],
        Resource = [
          "arn:aws:s3:::my-codepipeline-us-east-1-bucket1",
          "arn:aws:s3:::my-codepipeline-us-east-1-bucket1/*"
        ]
      }
    ]
  })
}