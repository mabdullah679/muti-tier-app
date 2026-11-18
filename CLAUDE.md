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
Terraform is not installed on the owner machine; `fmt`/`validate` run in CI only.

## Free path: Cloudflare Pages (prepared 2026-11-18, never deployed)
```
npm ci && npm run test:parity                  # 24 tests: Express vs functions/api/[[path]].js, same requests
npm run build:pages && npm run test:e2e        # React build + Playwright against local `wrangler pages dev`
npx wrangler pages deploy                      # LATER, owner-approved only (needs a Cloudflare token). No CI deploy job exists.
```
`functions/` is the API port (reuses `backend/src/validation.js`); any change to a backend route must change the Function and a parity case. Free limit: 100k Function requests/day. EKS/Terraform path unchanged. No `wrangler login`/deploy without the owner.

## Layout
`backend/` Express API, `frontend/` React + nginx, `k8s/` kustomize manifests, `terraform/` (root stack + modules) and `terraform/bootstrap/` (state bucket + OIDC role), `observability/` Grafana dashboard JSON, `scripts/` deploy/smoke/destroy, one workflow `.github/workflows/ci-cd-pipeline.yml`.

## Conventions
- Feature branch + PR to `main`; never push to `main`. A push to `prod-hardening` runs `terraform apply` against AWS (EKS, ~$0.26/h). Do not push there without the owner's say-so.
- Pin third-party actions to full commit SHAs with a version comment.
- Logic fixes need a test seen failing first (mutate, see red, reverse the exact edit).

## Do NOT
- Run `terraform apply`/`destroy`, `scripts/destroy.sh`, `kubectl` against a cluster, or any `aws` call without explicit owner consent. The stack was torn down 2026-10-20.
- Commit `.env`, tfstate, or generated passwords (Grafana admin password lives in SSM).
