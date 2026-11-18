output "project_name" {
  description = "Pages project name."
  value       = module.site.name
}

output "project_subdomain" {
  description = "Real *.pages.dev hostname."
  value       = module.site.subdomain
}

output "project_url" {
  description = "Production URL."
  value       = module.site.url
}
