#!/usr/bin/env bash
# Remove the application (not the cluster). The cluster, NLB and monitoring
# are removed with `terraform -chdir=terraform destroy` (see README).
set -euo pipefail
kubectl delete -k "$(dirname "$0")/../k8s" --ignore-not-found
