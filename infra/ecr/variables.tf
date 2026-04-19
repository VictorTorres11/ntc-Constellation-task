variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "repository_name" {
  description = "Name ECR repo"
  type        = string
}

variable "environment" {
  description = "Env tag"
  type        = string
  default     = "dev"
}
