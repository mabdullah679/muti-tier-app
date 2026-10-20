variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "name_prefix" {
  description = "Prefix for every named resource (shared AWS account)."
  type        = string
  default     = "pf-muti-tier-"
}

variable "kubernetes_version" {
  type    = string
  default = "1.34"
}

variable "node_instance_types" {
  description = "t3.medium (2 vCPU / 4 GiB): t3.small caps at 11 pods and 2 GiB, too tight for ingress + Prometheus + Grafana."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_count" {
  type    = number
  default = 2
}

variable "ci_role_arn" {
  description = "GitHub Actions deploy role; gets cluster-admin to deploy the app."
  type        = string
  default     = "arn:aws:iam::346208529954:role/pf-muti-tier-gha-deploy"
}

variable "extra_admin_principal_arns" {
  description = "Additional IAM role ARNs granted cluster-admin (e.g. an operator's role)."
  type        = list(string)
  default     = []
}
