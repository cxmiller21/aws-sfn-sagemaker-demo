terraform {
  required_version = ">= 1.5"
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "projects/sfn-sagemaker-demo/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
