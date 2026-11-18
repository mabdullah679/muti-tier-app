# Direct-upload Pages project: no `source` block, so Cloudflare does not build
# from Git. Builds are uploaded with `wrangler pages deploy`, not by Terraform.
resource "cloudflare_pages_project" "this" {
  account_id        = var.account_id
  name              = var.name
  production_branch = var.production_branch
}
