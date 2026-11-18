# Root module test, offline: mock_provider replaces the Cloudflare API, so no
# token or account is needed. Run: terraform init -backend=false && terraform test
# The resource-level assertions live in modules/pages_project/tests/.

mock_provider "cloudflare" {}

# The import block cannot run against a mock provider, so the resource is
# overridden: only Cloudflare-assigned (computed) values are supplied here.
override_resource {
  target = module.site.cloudflare_pages_project.this
  values = {
    subdomain = "multi-tier-app.pages.dev"
  }
}

variables {
  cloudflare_account_id = "test-account-id"
}

run "root_passes_project_through_child" {
  command = apply

  assert {
    condition     = output.project_name == "multi-tier-app"
    error_message = "project_name output must equal the existing project name (multi-tier-app)"
  }

  assert {
    condition     = output.project_subdomain == "multi-tier-app.pages.dev"
    error_message = "project_subdomain must come from the child module"
  }

  assert {
    condition     = output.project_url == "https://multi-tier-app.pages.dev"
    error_message = "project_url must be https:// plus the project subdomain"
  }
}
