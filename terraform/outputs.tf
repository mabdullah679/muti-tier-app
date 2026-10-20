output "cluster_name" { value = module.eks.cluster_name }
output "ecr_repository_urls" { value = module.ecr.repository_urls }
output "region" { value = var.region }
output "grafana_password_ssm_parameter" { value = aws_ssm_parameter.grafana_admin.name }
