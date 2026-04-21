terraform {
  backend "s3" {
    bucket         = "ntc-constellation-tfstate"
    key            = "ecr/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ECR repository with automatic image scanning and AES-256 encryption
# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  # enable automatic image scanning on push
  image_scanning_configuration {
    scan_on_push = true
  }

  # AES-256 encryption by default
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# lifecycle policy to remove untagged images older than 30 days
# Reference: https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images older than 30 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
