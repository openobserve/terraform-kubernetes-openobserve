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
