#!/usr/bin/env bash
# Deploy the app to the EKS cluster (replaces the old Minikube startup.sh).
# Usage: scripts/deploy-app.sh <image-tag>
# Needs: kubectl already pointed at the cluster, AWS creds for the account.
set -euo pipefail
TAG="${1:?usage: deploy-app.sh <image-tag>}"
REGION="${AWS_REGION:-ap-southeast-2}"
PREFIX="${NAME_PREFIX:-pf-muti-tier-}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$(dirname "$0")/../k8s/." "$WORK/"
cat >> "$WORK/kustomization.yaml" <<YAML
images:
  - name: backend
    newName: ${REGISTRY}/${PREFIX}backend
    newTag: "${TAG}"
  - name: frontend
    newName: ${REGISTRY}/${PREFIX}frontend
    newTag: "${TAG}"
YAML

kubectl apply -k "$WORK"
kubectl -n app rollout status deploy/backend --timeout=300s
kubectl -n app rollout status deploy/frontend --timeout=300s
