# Child module test, offline (mock provider). Run from this module directory:
#   terraform init -backend=false && terraform test

mock_provider "cloudflare" {
  mock_resource "cloudflare_pages_project" {
    defaults = {
      subdomain = "multi-tier-app.pages.dev"
    }
  }
}

variables {
  account_id = "test-account-id"
  name       = "multi-tier-app"
}

run "direct_upload_project_wiring" {
  command = plan

  assert {
    condition     = cloudflare_pages_project.this.name == "multi-tier-app"
    error_message = "Pages project name must be var.name (multi-tier-app)"
  }

  assert {
    condition     = cloudflare_pages_project.this.production_branch == "main"
    error_message = "production_branch must default to main"
  }

  assert {
    condition     = cloudflare_pages_project.this.account_id == "test-account-id"
    error_message = "account_id must come from var.account_id"
  }

  assert {
    condition     = cloudflare_pages_project.this.source == null
    error_message = "Direct-upload project: there must be no source block"
  }
}

run "outputs" {
  command = apply

  assert {
    condition     = output.name == "multi-tier-app"
    error_message = "name output must equal the project name"
  }

  assert {
    condition     = output.subdomain == "multi-tier-app.pages.dev"
    error_message = "subdomain output must be the Cloudflare-assigned hostname"
  }

  assert {
    condition     = output.url == "https://multi-tier-app.pages.dev"
    error_message = "url output must be https:// plus the subdomain"
  }
}
