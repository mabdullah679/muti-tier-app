# muti-tier-app

A React + Node two-tier web app run on Kubernetes (AWS EKS) behind an Nginx ingress, monitored with Prometheus and Grafana, and deployed by Terraform and GitHub Actions with no stored AWS keys.

Spec: this repo has no separate requirements document; the requirements are the original README goals (Nginx + Kubernetes, CI/CD pipeline, Prometheus/Grafana monitoring) plus the production-hardening brief tracked in [PR #1](https://github.com/mabdullah679/muti-tier-app/pull/1). Requirement IDs below are local: R1 frontend, R2 backend API, R3 ingress routing, R4 monitoring, R5 CI/CD, R6 infrastructure as code, R7 hardening.

```
 browser
   |  HTTP :80
   v
 Classic ELB (AWS)            <- created by the ingress-nginx Service
   |
   v
 ingress-nginx (namespace ingress-nginx)
   |-- /api/*  --> Service backend:3001 --> 2x Node/Express pods  (namespace app)
   |                                          |  /metrics (cluster-internal only)
   '-- /      --> Service frontend:80  --> 2x Nginx pods serving the React build
                                              ^
 Prometheus (namespace monitoring) --scrapes--'  ServiceMonitor "backend"
 Grafana (namespace monitoring, gp3 volume) --queries--> Prometheus

 GitHub Actions --OIDC--> IAM role --> Terraform (VPC, EKS, ECR, ingress, monitoring)
                                   --> docker build/push to ECR --> kubectl apply -k k8s/
```

Not contained in this repo: an AWS account (346208529954, ap-southeast-2) with the shared GitHub OIDC provider and the `portfolio-ci-boundary` IAM policy already present, and a GitHub repository with Actions enabled.

## Prerequisites

- To run the code locally: Node 20+, npm. Docker is optional (to build the images).
- To deploy: an AWS account as above, the AWS CLI, Terraform 1.10 or newer (state locking uses an S3 lockfile), `kubectl`, `gh`.
- Not needed on your machine: Minikube, a local Kubernetes cluster, Helm (Terraform's Helm provider does the installs), or any long-lived AWS keys.
- Ports used locally: backend 3001, frontend dev server 3000.

## Run it

Locally (identical on macOS, Linux, PowerShell, cmd):

1. `cd backend && npm ci && npm start` (listens on port 3001).
2. In a second terminal: `cd frontend && npm ci && npm start` (port 3000; `package.json` proxies `/api` to port 3001, mirroring what the ingress does in the cluster).
3. Open http://localhost:3000.

If a port is taken: backend `PORT=3002 npm start` (then change `proxy` in `frontend/package.json`), frontend `PORT=3100 npm start`.

On AWS (one-time bootstrap, then everything runs from GitHub Actions):

1. Bootstrap the state bucket and CI role: `terraform -chdir=terraform/bootstrap init && terraform -chdir=terraform/bootstrap apply` (local state; keep that state file).
2. Optional: grant yourself cluster-admin: `gh variable set EXTRA_ADMIN_ARNS --body '["arn:aws:iam::<acct>:role/<your-role>"]'`.
3. Deploy: push to `prod-hardening`, or `gh workflow run ci-cd-pipeline.yml --ref prod-hardening`. Takes about 25 minutes the first time (EKS creation dominates).
4. The URL is the ELB hostname: `kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'` after `aws eks update-kubeconfig --name pf-muti-tier-eks --region ap-southeast-2`.

Tear down (everything except bootstrap): `scripts/destroy.sh`. Remove bootstrap last: `terraform -chdir=terraform/bootstrap destroy`.

## What it does

| Action | Expected result | Req |
|---|---|---|
| Open `/` | React page loads from Nginx; shows "Backend OK (served by <pod>)" | R1, R3 |
| Submit a name in the form | `POST /api/greet` returns "Hello, <name>!" and the serving pod name; reload a few times to see both replicas | R1, R2 |
| Submit an empty or invalid name | 400 with a reason, shown in the UI | R2 |
| `GET /api/endpoint` | `{"message":"Hello from backend!"}` (original contract kept) | R2 |
| `GET /metrics` through the ingress | Not routed to the backend; the frontend's fallback page is returned | R3, R7 |
| Prometheus targets | Both backend pods `up`, request histogram per route and status | R4 |
| Grafana dashboard "Multi-Tier Backend" | Request rate, p95 latency, 5xx rate, memory per pod | R4 |
| Push to `prod-hardening` | Lint, tests, terraform fmt/validate/plan, apply, image push, deploy, smoke test | R5, R6 |
| SIGTERM to a backend pod | `/readyz` turns 503, drains for 5 s, exits 0 | R7 |

## Interface

| Method and path | Auth | Public via ingress |
|---|---|---|
| `GET /api/endpoint` | none | yes |
| `GET /api/health` | none | yes |
| `POST /api/greet` body `{"name": string}` (1-40 chars, letters/space/'/-/.) | none | yes |
| `GET /healthz`, `GET /readyz` (probes) | none | no (cluster only) |
| `GET /metrics` (Prometheus) | none | no (cluster only) |
| Grafana, Prometheus | Grafana admin password in SSM `/pf-muti-tier/grafana-admin-password` | no; use `kubectl port-forward` |

Backend config (environment): `PORT` (3001), `LOG_LEVEL` (info), `SHUTDOWN_DELAY_MS` (5000), `SHUTDOWN_TIMEOUT_MS` (15000). Invalid values stop startup with a clear error.

## Tests

- Backend: `cd backend && npm test` (13 tests, Node's built-in runner plus supertest) and `npm run lint`. No external services needed.
- Frontend: `cd frontend && CI=true npm test` (4 tests, Jest and Testing Library, `fetch` mocked) and `npm run lint`.
- Manifests: `kubectl kustomize k8s` must render.
- CI runs all of the above, then `terraform fmt -check`, `validate` and `plan`.
- Logic guards were mutation-checked: loosening the name-length check, disabling the shutdown branch of `/readyz`, removing the character-pattern check, and swallowing the API error message in the UI each turned a test red, and the edits were then reversed.
- Not covered by automated tests: the Terraform modules (checked by validate/plan/apply only), and the Grafana dashboard JSON.

## Layout

| Path | Role |
|---|---|
| [backend/src/app.js](backend/src/app.js) | Express app: routes, security headers, JSON logs, metrics, error handling |
| [backend/src/validation.js](backend/src/validation.js) | Input validation for `/api/greet` |
| [backend/src/server.js](backend/src/server.js) | Start-up and graceful shutdown |
| [backend/src/config.js](backend/src/config.js) | Environment configuration |
| [backend/test/app.test.js](backend/test/app.test.js) | Backend tests |
| [backend/Dockerfile](backend/Dockerfile) | Multi-stage, Node 20 Alpine, runs as uid 1000 |
| [frontend/src/App.js](frontend/src/App.js), [api.js](frontend/src/api.js) | UI and same-origin API calls |
| [frontend/nginx.conf](frontend/nginx.conf) | Unprivileged Nginx: SPA fallback, caching, CSP and other headers |
| [frontend/Dockerfile](frontend/Dockerfile) | Build with Node, serve with nginx-unprivileged (uid 101, port 8080) |
| [k8s/](k8s/) | Kustomize: namespace, deployments (probes, limits, non-root, read-only filesystem), services, PDBs, ServiceMonitor, ingress |
| [terraform/](terraform/) | Root stack: [main.tf](terraform/main.tf), [platform.tf](terraform/platform.tf) (gp3 class, ingress-nginx, kube-prometheus-stack) |
| [terraform/modules/vpc](terraform/modules/vpc/main.tf), [eks](terraform/modules/eks/main.tf), [ecr](terraform/modules/ecr/main.tf), [iam-oidc](terraform/modules/iam-oidc/main.tf) | Modules |
| [terraform/bootstrap/](terraform/bootstrap/main.tf) | State bucket and OIDC deploy role (applied once, locally) |
| [observability/backend-dashboard.json](observability/backend-dashboard.json) | Grafana dashboard, loaded by the sidecar |
| [scripts/](scripts/) | `deploy-app.sh`, `smoke-test.sh`, `internal-comms.sh`, `shutdown-app.sh`, `destroy.sh` (the old Minikube scripts, adapted) |
| [.github/workflows/ci-cd-pipeline.yml](.github/workflows/ci-cd-pipeline.yml) | Pipeline |

## Design decisions

- Classic ELB instead of an NLB or ALB: this AWS account rejects every elbv2 `CreateLoadBalancer` call ("This AWS account currently does not support creating load balancers"; seen in the Kubernetes service events). Classic ELB worked, so the ingress Service omits the NLB annotation. The AWS Load Balancer Controller would not help because it uses the same API.
- Two t3.medium on-demand nodes: a t3.small allows 11 pods and 2 GiB, too small for kube-system, ingress, Prometheus, Grafana and four app pods. On-demand rather than spot because a node reclaimed mid-demo costs more than the saving.
- Public subnets and no NAT gateway: a NAT gateway costs more per hour than a node. Nodes get public IPs for image pulls. The EKS API endpoint is public (IAM-authenticated) because CI runners have no fixed address.
- Kubernetes and Helm providers authenticate with `aws eks get-token` at call time. The first attempt used a token fetched at plan time and failed, because creating the cluster takes longer than the token's 15-minute life.
- EKS access entries (API auth mode) instead of the `aws-auth` ConfigMap, and Pod Identity instead of an OIDC provider for the EBS CSI driver, so no extra OIDC provider is created.
- Grafana is not exposed publicly: there is no TLS (no domain), and sending an admin password over plain HTTP is worse than needing `kubectl port-forward`.
- Images are tagged with the commit SHA and the repos are immutable; a re-run skips a push that already exists.
- The CI role can only touch resources named `pf-muti-tier-*`, carries the shared permissions boundary, and has an explicit deny on editing itself. EC2 is the exception: it is allowed account-wide within the region because EC2 actions cannot be scoped by name.
- The Grafana admin password is generated by Terraform, so it is also in the Terraform state (encrypted, versioned S3 bucket) as well as SSM.

## Deployed on AWS

Evidence from 2026-10-20 (ap-southeast-2):

- Pipeline run: https://github.com/mabdullah679/muti-tier-app/actions/runs/39396187816 (all three jobs green: test, plan, apply/deploy/smoke test). Earlier runs failed for the reasons in the design notes (token expiry, elbv2 blocked, operator TLS secret) and were fixed on the branch.
- URL pattern: `http://<id>-<number>.ap-southeast-2.elb.amazonaws.com/` (the ELB hostname is regenerated on every rebuild).
- Checked with curl against that hostname: `/` returned 200; `/api/endpoint` returned `{"message":"Hello from backend!"}`; `/api/health` returned status ok and the pod name; `POST /api/greet {"name":"Recruiter"}` returned "Hello, Recruiter!" from a different pod than the health call (both replicas serve traffic); an invalid name returned 400; `/metrics` through the ingress returned the HTML frontend, not metrics.
- Prometheus (via port-forward): both backend pods `up` on `/metrics`, with counters per route and status code. Grafana (via port-forward and its API): the "Multi-Tier Backend" dashboard is provisioned and a query for `sum(up{job="backend"})` returned data.
- Browser check: the page rendered, showed "Backend OK", and a submitted name came back as a greeting. This was loaded through a `kubectl port-forward` to the ingress controller because the test browser could not open the ELB hostname directly (curl could). The Grafana dashboard was not viewed in a browser.
- Resources (39 Terraform state entries): VPC, 2 public subnets, internet gateway and route table; EKS cluster `pf-muti-tier-eks` (1.34) with a managed node group of 2 t3.medium; add-ons pod-identity-agent and aws-ebs-csi-driver; 3 IAM roles plus the CI role; 2 ECR repos; SSM SecureString parameter; the ingress-nginx and kube-prometheus-stack Helm releases; one classic ELB and one 5 GiB gp3 volume created by Kubernetes.
- Cost while running: about $0.26 per hour, estimated: EKS control plane $0.10 (list price, from memory), 2 nodes $0.1056 (price API: $0.0528 each), classic ELB about $0.03, public IPv4 addresses about $0.02, EBS about $0.006.
- Torn down on 2026-10-20 after verification, to save cost. Afterwards, direct lookups in ap-southeast-2 found no EKS cluster, load balancer, EBS volume, ECR repository, `pf-muti-tier-*` S3 bucket or IAM role, VPC, subnet, network interface, security group, log group, KMS alias or SSM parameter carrying this project's name or tags, and the resource-tagging API reported 0 resources tagged `repo=muti-tier-app` (that API can lag). The shared OIDC provider and `portfolio-ci-boundary` policy were not touched.
- Rebuild (the state bucket and CI role were also removed, so bootstrap again first): `terraform -chdir=terraform/bootstrap init && terraform -chdir=terraform/bootstrap apply -auto-approve`, then `gh workflow run ci-cd-pipeline.yml --ref prod-hardening` (about 25 minutes). Destroy again with `scripts/destroy.sh`, then `terraform -chdir=terraform/bootstrap destroy`.
