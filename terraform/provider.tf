terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "volunteer-connect" # pinned — this machine's "default" profile points at a different account

  default_tags {
    tags = {
      Project = "volunteer-connect"
    }
  }
}
