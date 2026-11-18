variable "cloudflare_account_id" {
  description = "Cloudflare account ID. Not stored in the repo: pass via TF_VAR_cloudflare_account_id or terraform.tfvars (git-ignored)."
  type        = string
}

variable "project_name" {
  description = "Name of the existing Pages project to adopt."
  type        = string
  default     = "multi-tier-app"
}

variable "production_branch" {
  description = "Production branch of the Pages project."
  type        = string
  default     = "main"
}
