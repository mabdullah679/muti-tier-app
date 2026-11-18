# CLAUDE.md (muti-tier-app)

Global working rules: `~/.claude/CLAUDE.md` (read it; not copied here). Repo-specific only below.

## Commands (run 2026-11-18)

```
cd backend  && npm ci && npm run lint && npm test            # 13 passed (Node's built-in runner + supertest)
cd frontend && npm ci && npm run lint && CI=true npm test -- --no-watchman   # 4 passed
kubectl kustomize k8s > /dev/null                            # manifests render
docker build backend; docker build frontend                  # image builds
```
`--no-watchman`: on the owner's Mac, jest hangs forever with no output when watchman is installed. CI does not need the flag.
Terraform is not installed on the owner machine; run it via docker `hashicorp/terraform:1.12.2` (see Cloudflare section) or CI.

## Free path: Cloudflare Pages (live since 2026-11-18, deployed by hand)
```
npm ci && npm run test:parity                  # 24 tests: Express vs functions/api/[[path]].js, same requests
npm run build:pages && npm run test:e2e        # React build + Playwright against local `wrangler pages dev`
npx wrangler pages deploy                      # how the live site was deployed 2026-11-18 (owner's token). No CI deploy job exists.
```
`functions/` is the API port (reuses `backend/src/validation.js`); any change to a backend route must change the Function and a parity case. Free limit: 100k Function requests/day. EKS/Terraform path unchanged. No `wrangler login`/deploy without the owner.

## Layout
`backend/` Express API, `frontend/` React + nginx, `k8s/` kustomize manifests, `terraform/` (AWS root stack + modules), `infra/cloudflare/` (Pages project Terraform) and `terraform/bootstrap/` (state bucket + OIDC role), `observability/` Grafana dashboard JSON, `scripts/` deploy/smoke/destroy, one workflow `.github/workflows/ci-cd-pipeline.yml`.

## Conventions
- Feature branch + PR to `main`; never push to `main`. A push to `prod-hardening` runs `terraform apply` against AWS (EKS, ~$0.26/h). Do not push there without the owner's say-so.
- Pin third-party actions to full commit SHAs with a version comment.
- Logic fixes need a test seen failing first (mutate, see red, reverse the exact edit).

## Do NOT
- Run `terraform apply`/`destroy`, `scripts/destroy.sh`, `kubectl` against a cluster, or any `aws` call without explicit owner consent. The stack was torn down 2026-10-20.
- Commit `.env`, tfstate, or generated passwords (Grafana admin password lives in SSM).

## Cloudflare Pages + Terraform (`infra/cloudflare/`, added 2026-11-18)
- Live: https://multi-tier-app.pages.dev (project `multi-tier-app`), deployed by hand 2026-11-18 with `wrangler pages deploy`. No CD exists.
- Terraform manages the Pages PROJECT only (child `modules/pages_project`, root calls it as `module "site"`, `import {}` id `"${var.cloudflare_account_id}/${var.project_name}"`, provider `cloudflare/cloudflare ~> 5.29`, locked 5.29.0). The BUILD is deployed by `wrangler pages deploy`; Terraform never uploads builds.
- Offline checks (docker, no cloud): `docker run --rm -u $(id -u):$(id -g) -e HOME=/tmp -v "$PWD/infra/cloudflare":/w -w /w hashicorp/terraform:1.12.2 test` after `init -backend=false`; child module tests run the same way from `modules/pages_project`. CI job `terraform-cloudflare`.
- Credentials: `CLOUDFLARE_API_TOKEN` from the environment and `cloudflare_account_id` as a variable. Never write either into a file. No `terraform plan/apply`, wrangler deploy or Cloudflare API call without the owner; the first real `plan` was run 2026-11-18 and showed 1 import + 1 change (the provider's computed `build_image_auto_upgrade`, a v5 quirk; an API snapshot before/after the apply showed no config difference) and the import was then applied (state is local, in `infra/cloudflare/`, gitignored). A re-plan still shows that 1 change; anything else, or a replace, is a stop.
- Page subtitle (`frontend/src/App.js`) was EKS wording that is untrue on Pages; fixed 2026-11-18 to a deployment-neutral sentence.
