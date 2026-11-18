# The provider reads CLOUDFLARE_API_TOKEN from the environment. No token or
# account ID is written in any file.
provider "cloudflare" {}

module "site" {
  source = "./modules/pages_project"

  account_id        = var.cloudflare_account_id
  name              = var.project_name
  production_branch = var.production_branch
}

# Adopt the project that was created by hand on 2026-11-18 instead of
# recreating it. Import id format for cloudflare_pages_project: <account_id>/<project_name>
import {
  to = module.site.cloudflare_pages_project.this
  id = "${var.cloudflare_account_id}/${var.project_name}"
}
