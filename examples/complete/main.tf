# Production-grade HA OpenObserve deployment.
#
# Architecture:
#   - Multiple replicas for ingester, querier, and router
#   - External PostgreSQL for metadata (via DSN variable)
#   - Bundled NATS for cluster coordination and queuing
#   - AWS S3 for object storage (IRSA or static credentials)
#   - nginx Ingress with optional TLS (cert-manager)
#   - Per-component resource limits and node selectors
#
# Prerequisites:
#   - Kubernetes cluster with ≥ 3 worker nodes
#   - PostgreSQL 14+ instance (e.g. AWS RDS, CloudNativePG)
#   - S3 bucket with appropriate IAM permissions
#   - nginx-ingress-controller installed
#   - cert-manager installed (if using TLS)
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars   # fill in secrets
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

  # -----------------------------------------------------------------------
  # Authentication
  # -----------------------------------------------------------------------
  auth = {
    root_user_email    = var.root_user_email
    root_user_password = var.root_user_password
    postgres_dsn       = var.postgres_dsn
    s3_access_key      = var.s3_access_key
    s3_secret_key      = var.s3_secret_key
  }

  # -----------------------------------------------------------------------
  # HA replica counts
  # -----------------------------------------------------------------------
  replica_count = {
    ingester     = 3
    querier      = 2
    router       = 2
    compactor    = 1
    alertmanager = 1
  }

  # -----------------------------------------------------------------------
  # Backend stores (external PostgreSQL + bundled NATS)
  # -----------------------------------------------------------------------
  meta_store          = "postgres"
  cluster_coordinator = "nats"
  queue_store         = "nats"

  nats  = { enabled = true }
  minio = { enabled = false } # Using AWS S3

  # -----------------------------------------------------------------------
  # Object storage
  # -----------------------------------------------------------------------
  s3 = {
    provider    = "s3"
    region      = var.s3_region
    bucket_name = var.s3_bucket_name
  }

  # -----------------------------------------------------------------------
  # Data retention (1 year default; adjust to your compliance requirements)
  # -----------------------------------------------------------------------
  data_retention_days = 365

  # -----------------------------------------------------------------------
  # Ingress
  # -----------------------------------------------------------------------
  ingress = {
    enabled    = true
    class_name = "nginx"
    host       = var.ingress_host
    annotations = {
      "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/proxy-body-size"       = "0"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "600"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "600"
    }
    tls_secret_name = var.ingress_tls_secret != "" ? var.ingress_tls_secret : "${replace(var.ingress_host, ".", "-")}-tls"
  }

  # -----------------------------------------------------------------------
  # Persistent volumes
  # -----------------------------------------------------------------------
  persistence = {
    ingester = {
      enabled       = true
      size          = "100Gi"
      storage_class = var.storage_class
    }
    querier = {
      enabled       = true
      size          = "100Gi"
      storage_class = var.storage_class
    }
    alertmanager = {
      enabled       = true
      size          = "10Gi"
      storage_class = var.storage_class
    }
  }

  # -----------------------------------------------------------------------
  # Resource limits — tune to your workload
  # -----------------------------------------------------------------------
  resources = {
    ingester = {
      requests = { memory = "2Gi", cpu = "500m" }
      limits   = { memory = "8Gi", cpu = "2000m" }
    }
    querier = {
      requests = { memory = "2Gi", cpu = "500m" }
      limits   = { memory = "8Gi", cpu = "2000m" }
    }
    router = {
      requests = { memory = "256Mi", cpu = "100m" }
      limits   = { memory = "1Gi", cpu = "500m" }
    }
    compactor = {
      requests = { memory = "1Gi", cpu = "250m" }
      limits   = { memory = "4Gi", cpu = "1000m" }
    }
    alertmanager = {
      requests = { memory = "256Mi", cpu = "100m" }
      limits   = { memory = "1Gi", cpu = "500m" }
    }
  }

  # -----------------------------------------------------------------------
  # Node scheduling — pin storage-heavy components to dedicated nodes
  # -----------------------------------------------------------------------
  node_selector = {
    ingester  = { "node-role" = "openobserve-storage" }
    querier   = { "node-role" = "openobserve-storage" }
    compactor = { "node-role" = "openobserve-storage" }
  }

  tolerations = {
    ingester = [
      {
        key      = "openobserve-storage"
        operator = "Equal"
        value    = "true"
        effect   = "NoSchedule"
      }
    ]
    querier = [
      {
        key      = "openobserve-storage"
        operator = "Equal"
        value    = "true"
        effect   = "NoSchedule"
      }
    ]
    compactor = [
      {
        key      = "openobserve-storage"
        operator = "Equal"
        value    = "true"
        effect   = "NoSchedule"
      }
    ]
  }

  # -----------------------------------------------------------------------
  # Pod anti-affinity: spread ingesters across failure domains
  # -----------------------------------------------------------------------
  affinity = {
    ingester = {
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            podAffinityTerm = {
              labelSelector = {
                matchLabels = { "app.kubernetes.io/component" = "ingester" }
              }
              topologyKey = "kubernetes.io/hostname"
            }
          }
        ]
      }
    }
    querier = {
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            podAffinityTerm = {
              labelSelector = {
                matchLabels = { "app.kubernetes.io/component" = "querier" }
              }
              topologyKey = "kubernetes.io/hostname"
            }
          }
        ]
      }
    }
  }

  # -----------------------------------------------------------------------
  # Additional ZO_* config overrides
  # -----------------------------------------------------------------------
  config = {
    ZO_QUERY_TIMEOUT      = "300"
    ZO_HTTP_WORKER_NUM    = "8"
    ZO_DISK_CACHE_ENABLED = "true"
  }

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 900
}
