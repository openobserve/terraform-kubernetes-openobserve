output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (where EKS nodes run)."
  value       = module.vpc.private_subnets
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate for the cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_token" {
  description = "Authentication token for the EKS cluster."
  value       = data.aws_eks_cluster_auth.this.token
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN used for IRSA."
  value       = module.eks.oidc_provider_arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket created for OpenObserve data."
  value       = aws_s3_bucket.openobserve.bucket
}

output "s3_bucket_region" {
  description = "Region the S3 bucket was created in."
  value       = aws_s3_bucket.openobserve.region
}

output "irsa_role_arn" {
  description = "ARN of the IAM role for OpenObserve pods (IRSA). Annotate the Kubernetes service account with this value."
  value       = module.openobserve_irsa.iam_role_arn
}
