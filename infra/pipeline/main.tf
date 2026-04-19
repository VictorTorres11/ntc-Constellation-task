terraform {
  backend "s3" {
    bucket         = "ntc-constellation-tfstate"
    key            = "pipeline/terraform.tfstate"
    region         = "us-west-1"
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

data "aws_caller_identity" "current" {}
