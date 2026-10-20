#!/usr/bin/env bash
# In-cluster check: can the frontend pod reach the backend Service by DNS name?
# (EKS version of the old Minikube internal-comms.sh.)
set -euo pipefail
POD="$(kubectl -n app get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')"
kubectl -n app exec "$POD" -- wget -qO- http://backend:3001/api/endpoint
echo
