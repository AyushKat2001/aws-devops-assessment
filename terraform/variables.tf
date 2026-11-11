variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "github_user" {
  type    = string
  default = "ayush272001"
}

variable "github_repo" {
  type    = string
  default = "aws-devops-assessment"
}

variable "cluster_name" {
  type    = string
  default = "devops-assessment"
}

variable "ecr_repo_name" {
  type    = string
  default = "devops-assessment-app"
}

# Set to false if your AWS account already has the GitHub OIDC provider
variable "create_github_oidc_provider" {
  type    = bool
  default = true
}

# Set false if AWS has not verified your account for CloudFront yet
variable "enable_cloudfront" {
  type    = bool
  default = true
}
