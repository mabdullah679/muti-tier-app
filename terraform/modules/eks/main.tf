variable "name_prefix" { type = string }
variable "cluster_name" { type = string }
variable "kubernetes_version" { type = string }
variable "subnet_ids" { type = list(string) }
variable "permissions_boundary_arn" { type = string }
variable "instance_types" { type = list(string) }
variable "node_count" { type = number }
variable "node_disk_gb" {
  type    = number
  default = 20
}
variable "admin_principal_arns" {
  description = "IAM role ARNs granted cluster-admin through EKS access entries."
  type        = list(string)
}

data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name                 = "${var.name_prefix}eks-cluster"
  assume_role_policy   = data.aws_iam_policy_document.eks_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "node" {
  name                 = "${var.name_prefix}eks-node"
  assume_role_policy   = data.aws_iam_policy_document.node_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
  ])
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_eks_access_entry" "admin" {
  for_each      = toset(var.admin_principal_arns)
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.key
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  for_each      = aws_eks_access_entry.admin
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.instance_types
  capacity_type   = "ON_DEMAND"
  ami_type        = "AL2023_x86_64_STANDARD"
  disk_size       = var.node_disk_gb

  scaling_config {
    desired_size = var.node_count
    min_size     = var.node_count
    max_size     = var.node_count
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# --- EBS CSI driver (gp3 volumes for Grafana), credentials via Pod Identity ---
resource "aws_iam_role" "ebs_csi" {
  name                 = "${var.name_prefix}ebs-csi"
  assume_role_policy   = data.aws_iam_policy_document.pod_identity_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"
  depends_on   = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-ebs-csi-driver"
  pod_identity_association {
    role_arn        = aws_iam_role.ebs_csi.arn
    service_account = "ebs-csi-controller-sa"
  }
  depends_on = [aws_eks_addon.pod_identity_agent, aws_iam_role_policy_attachment.ebs_csi]
}

output "cluster_name" { value = aws_eks_cluster.this.name }
output "endpoint" { value = aws_eks_cluster.this.endpoint }
output "ca_data" { value = aws_eks_cluster.this.certificate_authority[0].data }
output "node_group_ready" { value = aws_eks_addon.ebs_csi.id }
