# without value or default will be asked
variable "terraform_aws_access_key" {}
variable "terraform_aws_secret_key" {}
variable "terraform_aws_region" {}

variable "amis" {
  type = map
  default = {
    # find ami on https://cloud-images.ubuntu.com/locator/ec2/ search example
    # us-east-1 hvm
    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html#finding-quick-start-ami
    us-east-1 = "ami-05c17b22914ce7378"
  }
}

variable "path_to_public_key" {
  default = "myapp_key.pub"
}

variable "rails_env" {
  default = "staging"
}

variable "rails_master_key" {
}

variable "instance_type" {
  default = "t3.small"
}

variable "instance_db_type" {
  default = "db.t3.micro"
}

variable "instance_redis_type" {
  default = "cache.t4g.micro"
}

variable "ruby_version" {
  type = string
  default = null
  description = "By default it ready from ../.ruby-version, but you can override here"
}

variable "bundler_version" {
  default = ""
}

variable "node_version" {
  default = "14.19.0"
}

variable "s3_bucket_name" {
  default = "myapp-uniq-bucket-name"
}
