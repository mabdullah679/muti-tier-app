# Cluster add-ons managed by Terraform: gp3 storage, Nginx ingress behind an
# NLB, and Prometheus + Grafana. The application itself is deployed by the
# pipeline from k8s/ once images exist.

resource "kubernetes_storage_class_v1" "gp3" {
  metadata { name = "gp3" }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  parameters             = { type = "gp3", encrypted = "true" }
  depends_on             = [module.eks]
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.12.1"
  wait             = true
  timeout          = 600

  values = [yamlencode({
    controller = {
      replicas = 1
      service = {
        # Classic ELB (no type annotation): this account's CreateLoadBalancer for
        # NLB/ALB (elbv2) returns OperationNotPermitted; classic ELB works.
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = "project=portfolio,repo=muti-tier-app,managed-by=terraform"
        }
      }
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { memory = "256Mi" }
      }
      metrics = { enabled = true }
    }
  })]

  depends_on = [module.eks]
}

resource "random_password" "grafana" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "grafana_admin" {
  name  = "/pf-muti-tier/grafana-admin-password"
  type  = "SecureString"
  value = random_password.grafana.result
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata { name = "monitoring" }
  depends_on = [module.eks]
}

resource "kubernetes_config_map_v1" "backend_dashboard" {
  metadata {
    name      = "backend-dashboard"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels    = { grafana_dashboard = "1" }
  }
  data = { "backend.json" = file("${path.module}/../observability/backend-dashboard.json") }
}

resource "helm_release" "monitoring" {
  name       = "kps"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "72.6.2"
  wait       = true
  timeout    = 900

  values = [yamlencode({
    alertmanager          = { enabled = false }
    nodeExporter          = { enabled = false }
    kubeEtcd              = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeProxy             = { enabled = false }
    prometheusOperator = {
      admissionWebhooks = { enabled = false }
      tls               = { enabled = false }
      resources         = { requests = { cpu = "20m", memory = "64Mi" }, limits = { memory = "192Mi" } }
    }
    prometheus = {
      prometheusSpec = {
        retention = "6h"
        # Pick up ServiceMonitors from every namespace, not only this release.
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        resources                               = { requests = { cpu = "100m", memory = "400Mi" }, limits = { memory = "800Mi" } }
      }
    }
    grafana = {
      persistence = {
        enabled          = true
        type             = "pvc"
        storageClassName = kubernetes_storage_class_v1.gp3.metadata[0].name
        size             = "5Gi"
      }
      resources = { requests = { cpu = "50m", memory = "128Mi" }, limits = { memory = "384Mi" } }
      sidecar   = { dashboards = { enabled = true, label = "grafana_dashboard", labelValue = "1", searchNamespace = "ALL" } }
    }
  })]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = random_password.grafana.result
  }

  depends_on = [helm_release.ingress_nginx, kubernetes_storage_class_v1.gp3]
}
