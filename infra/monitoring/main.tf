terraform {
  backend "s3" {
    bucket         = "ntc-constellation-tfstate"
    key            = "monitoring/terraform.tfstate"
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

# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb
data "aws_lb" "this" {
  name = "${var.project_name}-alb"
}
