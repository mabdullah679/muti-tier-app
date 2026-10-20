#!/usr/bin/env bash
# Smoke test against the public NLB hostname. Usage: scripts/smoke-test.sh [host]
# With no argument, reads the hostname from the ingress controller Service.
set -euo pipefail
HOST="${1:-$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')}"
BASE="http://${HOST}"
fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }

# A fresh NLB takes a few minutes for DNS and targets to come up.
for i in $(seq 1 60); do
  code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "${BASE}/api/health" || true)"
  [ "$code" = "200" ] && break
  echo "waiting for ${BASE} (attempt $i, last status ${code})..."
  sleep 10
done
[ "$code" = "200" ] || fail "/api/health never returned 200"

curl -fsS "${BASE}/" | grep -q '<div id="root">' || fail "frontend index not served"
curl -fsS "${BASE}/api/endpoint" | grep -q 'Hello from backend!' || fail "/api/endpoint wrong body"
curl -fsS -XPOST "${BASE}/api/greet" -H 'content-type: application/json' -d '{"name":"Smoke"}' | grep -q 'Hello, Smoke!' || fail "greet failed"
status="$(curl -s -o /dev/null -w '%{http_code}' -XPOST "${BASE}/api/greet" -H 'content-type: application/json' -d '{"name":""}')"
[ "$status" = "400" ] || fail "invalid input should be 400, got $status"
echo "SMOKE OK: ${BASE}"
