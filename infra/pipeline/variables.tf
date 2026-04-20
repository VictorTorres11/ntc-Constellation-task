variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ntc-constellation"
}

variable "environment" {
  description = "Env tag"
  type        = string
  default     = "dev"
}

variable "github_org" {
  description = "GitHub org or user that owns the repo"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name"
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR repo name"
  type        = string
  default     = "ntc-constellation-api"
}

variable "ecs_execution_role_arn" {
  description = "ARN ECS execution role"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN ECS task role"
  type        = string
}
