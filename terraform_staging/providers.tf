terraform {
  required_providers {
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94.1"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  # comment if you want current `aws configure` to be used
  access_key = var.terraform_aws_access_key
  secret_key = var.terraform_aws_secret_key
  region     = var.terraform_aws_region
  default_tags {
    tags = {
      # Active Cost allocation tag
      created_by = "myapp"
    }
  }
}

# If you are using s3 to store state you need to export AWS keys that has access
# to the bucket (we can not use provider "aws" keys since backend is initialized
# before providers) and also you need to create bucket before starting terraform
# You can use the same as terraform_aws_secret_key keys but we need to export:
# export AWS_ACCESS_KEY_ID=AK... AWS_SECRET_ACCESS_KEY=0P...
# or
# set -a && source terraform.tfvars && set +a
# export AWS_ACCESS_KEY_ID=$terraform_aws_access_key AWS_SECRET_ACCESS_KEY=$terraform_aws_secret_key
#
# aws s3api create-bucket --bucket myapp-capistrano-terraform-state --region us-east-1
# optional
# aws s3api put-bucket-versioning --bucket myapp-capistrano-terraform-state --region us-east-1 --versioning-configuration Status=Enabled
terraform {
  backend "s3" {
    bucket         = "myapp-capistrano-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
