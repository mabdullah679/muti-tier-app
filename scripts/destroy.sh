#!/usr/bin/env bash
# Tear the whole AWS stack down (EKS, nodes, classic ELB, VPC, ECR, SSM param).
# Needs Terraform >= 1.10 and the `aws` CLI, with credentials for the account.
# Does NOT remove the bootstrap (state bucket + CI role): see README, last step.
set -euo pipefail
[ "$(aws sts get-caller-identity --query Account --output text)" = "346208529954" ] || { echo "wrong AWS account" >&2; exit 1; }
cd "$(dirname "$0")/../terraform"
terraform init -input=false
terraform destroy -input=false -auto-approve \
  -var "extra_admin_principal_arns=${EXTRA_ADMIN_ARNS:-[]}"

echo "--- leftovers check (each list should be empty) ---"
aws eks list-clusters --region ap-southeast-2 --query "clusters[?starts_with(@, 'pf-muti-tier-')]" --output text
aws ec2 describe-volumes --region ap-southeast-2 --filters "Name=tag:repo,Values=muti-tier-app" --query 'Volumes[].VolumeId' --output text
aws ec2 describe-vpcs --region ap-southeast-2 --filters "Name=tag:Name,Values=pf-muti-tier-vpc" --query 'Vpcs[].VpcId' --output text
