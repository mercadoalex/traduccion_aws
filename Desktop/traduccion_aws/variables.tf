# Define the variable for the English content S3 bucket name
variable "en_bucket_name" {
  type = string
}

# Define the variable for the Spanish content S3 bucket name
variable "es_bucket_name" {
  type = string
}

# Define the variable for the CodePipeline S3 bucket name
variable "codepipeline_bucket_name" {
  type = string
}

# Define the variable for the GitHub repository URL
variable "github_repository_url" {
  type = string
}