terraform {
  required_version = ">= 1.7, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region                      = var.aws_region
  access_key                  = var.use_local_emulator ? "test" : null
  secret_key                  = var.use_local_emulator ? "test" : null
  skip_credentials_validation = var.use_local_emulator
  skip_metadata_api_check     = var.use_local_emulator
  skip_requesting_account_id  = var.use_local_emulator
  default_tags {
    tags = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform" }
  }
  endpoints {
    ec2                    = var.use_local_emulator ? var.ec2_endpoint : null
    ecs                    = var.use_local_emulator ? var.aws_endpoint : null
    ecr                    = var.use_local_emulator ? var.aws_endpoint : null
    efs                    = var.use_local_emulator ? var.aws_endpoint : null
    iam                    = var.use_local_emulator ? var.aws_endpoint : null
    sts                    = var.use_local_emulator ? var.aws_endpoint : null
    cloudwatchlogs         = var.use_local_emulator ? var.aws_endpoint : null
    elasticloadbalancingv2 = var.use_local_emulator ? var.aws_endpoint : null
  }
}
