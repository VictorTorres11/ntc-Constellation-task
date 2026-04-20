variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
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
