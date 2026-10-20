# One-time bootstrap: the Terraform state bucket and the GitHub OIDC deploy
# role. Applied locally (a chicken-and-egg step: CI needs the role and the
# bucket before it can run). Its own state is local and never committed.
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}
variable "name_prefix" {
  type    = string
  default = "pf-muti-tier-"
}
variable "github_repo" {
  type    = string
  default = "mabdullah679/muti-tier-app"
}
variable "github_branch" {
  type    = string
  default = "prod-hardening"
}

provider "aws" {
  region              = var.region
  allowed_account_ids = ["346208529954"]
  default_tags {
    tags = {
      project      = "portfolio"
      repo         = "muti-tier-app"
      "managed-by" = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  bucket = "${var.name_prefix}tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "iam_oidc" {
  source                   = "../modules/iam-oidc"
  name_prefix              = var.name_prefix
  github_repo              = var.github_repo
  github_branch            = var.github_branch
  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/portfolio-ci-boundary"
  state_bucket             = local.bucket
  region                   = var.region
  account_id               = data.aws_caller_identity.current.account_id
}

output "state_bucket" { value = aws_s3_bucket.state.id }
output "ci_role_arn" { value = module.iam_oidc.role_arn }
