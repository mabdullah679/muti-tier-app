variable "account_id" {
  description = "Cloudflare account ID that owns the Pages project."
  type        = string
}

variable "name" {
  description = "Pages project name (the part before .pages.dev, unless Cloudflare appended a suffix)."
  type        = string
}

variable "production_branch" {
  description = "Git branch Cloudflare treats as production. Direct-upload projects have no Git source, but the field is required."
  type        = string
  default     = "main"
}
