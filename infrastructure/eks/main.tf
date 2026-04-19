# ============================================================
# EKS Cluster (Control Plane)
# ============================================================
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true

    public_access_cidrs = var.public_access_cidrs
  }

  # OIDC Provider: necesario para IRSA
  enabled_cluster_log_types = var.cluster_log_types

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

  tags = {
    Name  = var.cluster_name
    Owner = var.owner
  }
}


data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name  = "${var.cluster_name}-oidc-provider"
    Owner = var.owner
  }
}


resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node_group.arn

  
  subnet_ids = var.private_subnet_ids


  capacity_type  = var.capacity_type
  instance_types = var.instance_types


  disk_size = var.node_disk_size

  scaling_config {
    desired_size = var.desired_nodes
    min_size     = var.min_nodes
    max_size     = var.max_nodes
  }


  update_config {
    max_unavailable = 1
  }


  labels = merge(
    {
      "role"         = "worker"
      "cluster-name" = var.cluster_name
    },
    var.node_labels
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_registry_policy,
  ]

  tags = {
    Name  = "${var.cluster_name}-node-group"
    Owner = var.owner
  }
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}