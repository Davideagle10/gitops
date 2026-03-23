output "cluster_name" {
  description = "EKS name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Certificate CA"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_version" {
  description = "k8s version"
  value       = aws_eks_cluster.main.version
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL"
  value       = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")
}

output "node_group_role_arn" {
  description = "ARN IAM role "
  value       = aws_iam_role.node_group.arn
}