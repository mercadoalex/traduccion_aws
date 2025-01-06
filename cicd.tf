# Create a CodeStar connection to GitHub
resource "aws_codestarconnections_connection" "codestar_connection" {
  name          = "app-dev-codestar" # Name of the CodeStar connection
  provider_type = "GitHub"           # Type of provider (GitHub in this case)
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
      name             = "Build"           # Name of the action
      category         = "Build"           # Category of the action (Build in this case)
      owner            = "AWS"             # Owner of the action (AWS in this case)
      provider         = "CodeBuild"       # Provider of the action (CodeBuild in this case)
      version          = "1"               # Version of the action
      input_artifacts  = ["source_output"] # Input artifacts for the action
      output_artifacts = ["build_output"]  # Output artifacts from the action

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name # Name of the CodeBuild project
      }
    }
  }
}

# Create an S3 bucket for CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = var.codepipeline_bucket_name
  force_destroy = true # Allow Terraform to delete the bucket and its contents
}

# IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name               = "codepipeline_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# IAM policy document for CodePipeline
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# IAM policy for CodePipeline
resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "codepipeline_policy"
  role   = aws_iam_role.codepipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
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
      aws_s3_bucket.codepipeline_bucket.arn,
      "${aws_s3_bucket.codepipeline_bucket.arn}/*"
    ]
  }

  statement {
    actions = [
      "codestar-connections:UseConnection"
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["*"]
  }
}

# Create a CodeBuild project
resource "aws_codebuild_project" "build_project" {
  name         = "my-build-project"
  description  = "CodeBuild project for building the application"
  service_role = aws_iam_role.codebuild_service_role.arn # ARN of the IAM role for CodeBuild

  artifacts {
    type = "CODEPIPELINE" # Use CodePipeline as the artifact store
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"       # Compute type for the build environment
    image        = "aws/codebuild/standard:4.0" # Docker image for the build environment
    type         = "LINUX_CONTAINER"            # Type of build environment
  }

  source {
    type      = "CODEPIPELINE"  # Use CodePipeline as the source
    buildspec = "buildspec.yml" # Path to the buildspec file
  }
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

# IAM policy for CodeBuild
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
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.codepipeline_bucket.arn,
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
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