output "namespace" {
  description = "Kubernetes namespace where OpenObserve is deployed."
  value       = module.openobserve.namespace
}

output "http_endpoint" {
  description = "In-cluster HTTP endpoint for OpenObserve."
  value       = module.openobserve.http_endpoint
}

output "grpc_endpoint" {
  description = "In-cluster gRPC endpoint for OpenTelemetry exporters."
  value       = module.openobserve.grpc_endpoint
}

output "ingress_host" {
  description = "Public hostname for the OpenObserve UI."
  value       = module.openobserve.ingress_host
}

output "public_url" {
  description = "HTTPS URL for the OpenObserve UI (requires DNS and TLS to be fully propagated)."
  value       = "https://${module.openobserve.ingress_host}"
}

output "app_version" {
  description = "Deployed OpenObserve application version."
  value       = module.openobserve.app_version
}

output "status" {
  description = "Helm release status."
  value       = module.openobserve.status
}
