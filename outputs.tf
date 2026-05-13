output "release_name" {
  description = "Name of the deployed Helm release."
  value       = helm_release.this.name
}

output "namespace" {
  description = "Kubernetes namespace where OpenObserve is deployed."
  value       = helm_release.this.namespace
}

output "chart_version" {
  description = "Version of the deployed Helm chart."
  value       = helm_release.this.version
}

output "app_version" {
  description = "Application version reported by the Helm chart metadata."
  value       = helm_release.this.metadata[0].app_version
}

output "status" {
  description = "Current Helm release status (e.g. deployed, failed)."
  value       = helm_release.this.status
}

output "service_name" {
  description = "Kubernetes Service name for the OpenObserve router (entry point for all traffic)."
  value       = "${helm_release.this.name}-router"
}

output "http_endpoint" {
  description = "In-cluster HTTP endpoint for the OpenObserve UI and ingestion API."
  value       = "http://${helm_release.this.name}-router.${helm_release.this.namespace}.svc.cluster.local:${var.service.http_port}"
}

output "grpc_endpoint" {
  description = "In-cluster gRPC endpoint used by OpenTelemetry exporters."
  value       = "${helm_release.this.name}-router.${helm_release.this.namespace}.svc.cluster.local:${var.service.grpc_port}"
}

output "ingress_host" {
  description = "Ingress hostname, or empty string when ingress is disabled."
  value       = var.ingress.enabled ? var.ingress.host : ""
}

# ---------------------------------------------------------------------------
# Capacity recommendations
# ---------------------------------------------------------------------------

output "capacity_recommendations" {
  description = <<-EOT
    Capacity planning recommendations derived from your ingestion_gb_per_day input.
    Use these to right-size replicas, EKS nodes, and plan AWS spend before applying.
    Set capacity.ingestion_gb_per_day to enable.
  EOT
  value = local.cap_enabled ? {
    deployment_mode                 = local.recommended_mode
    replica_counts                  = local.recommended_replicas
    total_cpu_cores                 = local.total_cpu_cores
    s3_storage_gb                   = local.s3_storage_gb
    eks_instance_type               = local.recommended_instance_type
    eks_node_count                  = local.recommended_node_count
    estimated_monthly_cost_usd      = local.estimated_monthly_cost_usd
    estimated_price_per_gb_ingested = local.estimated_price_per_gb_ingested
  } : null
}

# ---------------------------------------------------------------------------
# AWS infrastructure outputs (only when create_aws_infrastructure = true)
# ---------------------------------------------------------------------------

output "aws_infrastructure" {
  description = "AWS resource details created by the module. Null when create_aws_infrastructure = false."
  value = var.create_aws_infrastructure ? {
    vpc_id           = module.aws_infrastructure[0].vpc_id
    cluster_name     = module.aws_infrastructure[0].cluster_name
    cluster_endpoint = module.aws_infrastructure[0].cluster_endpoint
    s3_bucket_name   = module.aws_infrastructure[0].s3_bucket_name
    irsa_role_arn    = module.aws_infrastructure[0].irsa_role_arn
  } : null
}
