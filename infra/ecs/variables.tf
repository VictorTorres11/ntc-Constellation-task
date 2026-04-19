variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "project_name" {
  description = "Project name used as prefix for rn"
  type        = string
  default     = "ntc-constellation"
}

variable "environment" {
  description = "Env tag"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ecr_repository_url" {
  description = "ECR repo URL for the application image"
  type        = string
}

variable "app_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "app_port" {
  description = "Container port the application listens on"
  type        = number
  default     = 8080
}
