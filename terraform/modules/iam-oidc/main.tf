variable "name_prefix" { type = string }
variable "github_repo" { type = string } # owner/name
variable "github_branch" { type = string }
variable "permissions_boundary_arn" { type = string }
variable "state_bucket" { type = string }
variable "region" { type = string }
variable "account_id" { type = string }

# Shared GitHub OIDC provider, created outside this repo.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  role_name = "${var.name_prefix}gha-deploy"
  role_arn  = "arn:aws:iam::${var.account_id}:role/${local.role_name}"
  prefix    = trimsuffix(var.name_prefix, "-")
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only this repo, and only the deploy branch or pull requests targeting it.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/${var.github_branch}",
        "repo:${var.github_repo}:pull_request",
      ]
    }
  }
}

data "aws_iam_policy_document" "permissions" {
  statement {
    sid       = "Network"
    actions   = ["ec2:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }
  statement {
    sid       = "Eks"
    actions   = ["eks:*"]
    resources = ["arn:aws:eks:${var.region}:${var.account_id}:*/${var.name_prefix}*"]
  }
  statement {
    sid       = "EksRead"
    actions   = ["eks:Describe*", "eks:List*", "eks:AccessKubernetesApi"]
    resources = ["*"]
  }
  statement {
    sid       = "Ecr"
    actions   = ["ecr:*"]
    resources = ["arn:aws:ecr:${var.region}:${var.account_id}:repository/${var.name_prefix}*"]
  }
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "IamPrefixed"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:TagRole", "iam:UntagRole", "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:PassRole",
    ]
    resources = ["arn:aws:iam::${var.account_id}:role/${var.name_prefix}*"]
  }
  statement {
    sid       = "IamRead"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }
  statement {
    sid       = "IamServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${var.account_id}:role/aws-service-role/*"]
  }
  statement {
    sid       = "SsmPrefixed"
    actions   = ["ssm:PutParameter", "ssm:DeleteParameter", "ssm:GetParameter*", "ssm:AddTagsToResource", "ssm:RemoveTagsFromResource", "ssm:ListTagsForResource"]
    resources = ["arn:aws:ssm:${var.region}:${var.account_id}:parameter/${local.prefix}/*"]
  }
  statement {
    sid       = "SsmList"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }
  statement {
    sid       = "StateBucket"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketVersioning"]
    resources = ["arn:aws:s3:::${var.state_bucket}", "arn:aws:s3:::${var.state_bucket}/*"]
  }
  statement {
    sid       = "LoadBalancerRead"
    actions   = ["elasticloadbalancing:Describe*"]
    resources = ["*"]
  }
  # The CI role may not rewrite itself.
  statement {
    sid       = "DenySelfModification"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = [local.role_arn]
  }
}

resource "aws_iam_role" "ci" {
  name                 = local.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  permissions_boundary = var.permissions_boundary_arn
  max_session_duration = 7200
}

resource "aws_iam_role_policy" "ci" {
  name   = "${var.name_prefix}gha-deploy"
  role   = aws_iam_role.ci.id
  policy = data.aws_iam_policy_document.permissions.json
}

output "role_arn" { value = aws_iam_role.ci.arn }
