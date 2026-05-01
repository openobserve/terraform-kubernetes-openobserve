# Minimal single-node OpenObserve deployment.
#
# Uses local SQLite storage and in-process coordination — no external
# PostgreSQL or NATS required.  Suitable for development, CI, and evaluation.
# Not suitable for production: single point of failure, no HA, no S3 offload.
#
# Prerequisites:
#   - A running Kubernetes cluster with kubectl access
#   - Default StorageClass configured in the cluster
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars   # fill in credentials
#   terraform init
#   terraform plan
#   terraform apply

module "openobserve" {
  # Local path for development; switch to registry source for production use:
  # source  = "openobserve/openobserve/kubernetes"
  # version = "~> 1.0"
  source = "../../"

  namespace     = "openobserve"
  release_name  = "openobserve"
  chart_version = "0.80.3"

  auth = {
    root_user_email    = var.root_user_email
    root_user_password = var.root_user_password
  }

  # Single-node local mode: all state is stored on disk in the pod.
  # Switch to meta_store = "postgres" + cluster_coordinator = "nats" for HA.
  meta_store          = "sqlite"
  cluster_coordinator = "local"
  queue_store         = "local"

  # Disable bundled NATS and MinIO — not needed in local mode
  nats  = { enabled = false }
  minio = { enabled = false }

  # Keep storage small for non-production use
  persistence = {
    ingester = {
      enabled = true
      size    = "10Gi"
    }
    querier = {
      enabled = true
      size    = "10Gi"
    }
    alertmanager = {
      enabled = true
      size    = "2Gi"
    }
  }

  # Expose via port-forward; set ingress.enabled = true if you have an ingress controller
  service = { type = "ClusterIP" }

  wait = true
}
