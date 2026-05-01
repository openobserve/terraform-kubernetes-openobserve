output "namespace" {
  description = "Kubernetes namespace where OpenObserve is deployed."
  value       = module.openobserve.namespace
}

output "http_endpoint" {
  description = "In-cluster HTTP endpoint. Port-forward with: kubectl port-forward -n openobserve svc/openobserve-router 5080:5080"
  value       = module.openobserve.http_endpoint
}

output "status" {
  description = "Helm release status."
  value       = module.openobserve.status
}
