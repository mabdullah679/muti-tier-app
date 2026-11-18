output "name" {
  description = "Pages project name."
  value       = cloudflare_pages_project.this.name
}

output "subdomain" {
  description = "Real *.pages.dev hostname Cloudflare assigned (may carry a suffix, e.g. ui-builder-emg.pages.dev)."
  value       = cloudflare_pages_project.this.subdomain
}

output "url" {
  description = "Production URL."
  value       = "https://${cloudflare_pages_project.this.subdomain}"
}
