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
  cluster_name = "${var.name_prefix}eks"
  boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/portfolio-ci-boundary"
}

module "vpc" {
  source       = "./modules/vpc"
  name_prefix  = var.name_prefix
  cluster_name = local.cluster_name
}

module "ecr" {
  source       = "./modules/ecr"
  name_prefix  = var.name_prefix
  repositories = ["backend", "frontend"]
}

module "eks" {
  source                   = "./modules/eks"
  name_prefix              = var.name_prefix
  cluster_name             = local.cluster_name
  kubernetes_version       = var.kubernetes_version
  subnet_ids               = module.vpc.public_subnet_ids
  permissions_boundary_arn = local.boundary_arn
  instance_types           = var.node_instance_types
  node_count               = var.node_count
  admin_principal_arns     = concat([var.ci_role_arn], var.extra_admin_principal_arns)
}

# Tokens are fetched by the AWS CLI at call time (exec), not once at plan
# time: cluster + node group creation takes longer than a token's 15 minutes.
locals {
  exec_args = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.region]
}

provider "kubernetes" {
  host                   = module.eks.endpoint
  cluster_ca_certificate = base64decode(module.eks.ca_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.exec_args
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.endpoint
    cluster_ca_certificate = base64decode(module.eks.ca_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = local.exec_args
    }
  }
}
