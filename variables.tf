# ---------------------------------------------------------------------------
# Release configuration
# ---------------------------------------------------------------------------

variable "release_name" {
  description = "Name of the Helm release."
  type        = string
  default     = "openobserve"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$", var.release_name))
    error_message = "release_name must be a valid DNS label (lowercase alphanumeric and hyphens, max 63 chars)."
  }
}

variable "namespace" {
  description = "Kubernetes namespace to deploy OpenObserve into."
  type        = string
  default     = "openobserve"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", var.namespace))
    error_message = "namespace must be a valid Kubernetes namespace name."
  }
}

variable "create_namespace" {
  description = "Create the Kubernetes namespace if it does not exist."
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "Version of the openobserve Helm chart. Pin this for reproducible deployments."
  type        = string
  default     = "0.80.3"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "chart_version must be a semver string, e.g. 0.80.3."
  }
}

variable "timeout" {
  description = "Timeout in seconds for Helm install/upgrade operations."
  type        = number
  default     = 600

  validation {
    condition     = var.timeout >= 60
    error_message = "timeout must be at least 60 seconds."
  }
}

variable "atomic" {
  description = "Automatically roll back the release on install/upgrade failure."
  type        = bool
  default     = false
}

variable "cleanup_on_fail" {
  description = "Delete newly created resources when an upgrade fails."
  type        = bool
  default     = false
}

variable "wait" {
  description = "Wait for all pods and services to be ready before marking the release as successful."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Image
# ---------------------------------------------------------------------------

variable "image" {
  description = <<-EOT
    Container image configuration.
    Set repository to 'o2cr.ai/openobserve/openobserve-enterprise' for the enterprise edition.
    Leave tag empty to use the chart's default version.
  EOT
  type = object({
    repository  = optional(string, "o2cr.ai/openobserve/openobserve")
    tag         = optional(string, "")
    pull_policy = optional(string, "IfNotPresent")
  })
  default = {}

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.image.pull_policy)
    error_message = "image.pull_policy must be one of: Always, IfNotPresent, Never."
  }
}

variable "image_pull_secrets" {
  description = "List of Kubernetes Secret names used to pull the container image."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Replica counts
# ---------------------------------------------------------------------------

variable "replica_count" {
  description = "Number of replicas per component. Increase querier/ingester for HA; router is stateless and scales horizontally."
  type = object({
    ingester     = optional(number, 1)
    querier      = optional(number, 1)
    router       = optional(number, 1)
    compactor    = optional(number, 1)
    alertmanager = optional(number, 1)
  })
  default = {}

  validation {
    condition     = var.replica_count.ingester >= 1
    error_message = "replica_count.ingester must be at least 1."
  }

  validation {
    condition     = var.replica_count.querier >= 1
    error_message = "replica_count.querier must be at least 1."
  }

  validation {
    condition     = var.replica_count.router >= 1
    error_message = "replica_count.router must be at least 1."
  }
}

# ---------------------------------------------------------------------------
# Authentication (stored in a Kubernetes Secret by the chart)
# ---------------------------------------------------------------------------

variable "auth" {
  description = <<-EOT
    Authentication credentials. All values are stored in a Kubernetes Secret.
    root_user_email and root_user_password are required.
    Provide s3_access_key / s3_secret_key for AWS-signature S3 auth.
    Provide postgres_dsn for PostgreSQL metadata store.
  EOT
  type = object({
    root_user_email    = string
    root_user_password = string
    root_user_token    = optional(string, "")
    s3_access_key      = optional(string, "")
    s3_secret_key      = optional(string, "")
    postgres_dsn       = optional(string, "")
    postgres_ro_dsn    = optional(string, "")
  })
  sensitive = true

  validation {
    condition     = length(var.auth.root_user_email) > 0 && can(regex("^[^@]+@[^@]+\\.[^@]+$", var.auth.root_user_email))
    error_message = "auth.root_user_email must be a valid email address."
  }

  validation {
    condition     = length(var.auth.root_user_password) >= 8
    error_message = "auth.root_user_password must be at least 8 characters."
  }
}

# ---------------------------------------------------------------------------
# Metadata / coordination backend
# ---------------------------------------------------------------------------

variable "meta_store" {
  description = "Metadata storage backend. Use 'postgres' for all HA deployments."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql", "sqlite", "etcd"], var.meta_store)
    error_message = "meta_store must be one of: postgres, mysql, sqlite, etcd."
  }
}

variable "cluster_coordinator" {
  description = "Cluster coordination backend. 'nats' is required for multi-node deployments."
  type        = string
  default     = "nats"

  validation {
    condition     = contains(["nats", "etcd", "local"], var.cluster_coordinator)
    error_message = "cluster_coordinator must be one of: nats, etcd, local."
  }
}

variable "queue_store" {
  description = "Distributed queue backend. 'nats' is required for multi-node deployments."
  type        = string
  default     = "nats"

  validation {
    condition     = contains(["nats", "redis", "local"], var.queue_store)
    error_message = "queue_store must be one of: nats, redis, local."
  }
}

# ---------------------------------------------------------------------------
# Object storage (S3-compatible)
# ---------------------------------------------------------------------------

variable "s3" {
  description = <<-EOT
    S3-compatible object storage configuration.
    OpenObserve uses S3 for long-term data persistence.
    Set server_url to use MinIO or other S3-compatible providers.
  EOT
  type = object({
    provider      = optional(string, "s3")
    region        = optional(string, "us-east-1")
    bucket_name   = optional(string, "")
    server_url    = optional(string, "")
    bucket_prefix = optional(string, "")
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Data retention
# ---------------------------------------------------------------------------

variable "data_retention_days" {
  description = "Days to retain data before compaction removes it (ZO_COMPACT_DATA_RETENTION_DAYS)."
  type        = number
  default     = 3650

  validation {
    condition     = var.data_retention_days >= 1 && var.data_retention_days <= 36500
    error_message = "data_retention_days must be between 1 and 36500."
  }
}

# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

variable "service" {
  description = "Kubernetes Service configuration for the router component."
  type = object({
    type      = optional(string, "ClusterIP")
    http_port = optional(number, 5080)
    grpc_port = optional(number, 5081)
  })
  default = {}

  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service.type)
    error_message = "service.type must be one of: ClusterIP, NodePort, LoadBalancer."
  }
}

# ---------------------------------------------------------------------------
# Ingress
# ---------------------------------------------------------------------------

variable "ingress" {
  description = <<-EOT
    Ingress configuration. Enable to expose OpenObserve externally.
    Requires an Ingress controller (e.g. nginx-ingress) in the cluster.
    Set tls_secret_name to enable HTTPS with cert-manager.
  EOT
  type = object({
    enabled         = optional(bool, false)
    class_name      = optional(string, "nginx")
    host            = optional(string, "")
    annotations     = optional(map(string), {})
    tls_secret_name = optional(string, "")
  })
  default = {}

  validation {
    condition     = !var.ingress.enabled || length(var.ingress.host) > 0
    error_message = "ingress.host must be set when ingress.enabled is true."
  }
}

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

variable "persistence" {
  description = "Persistent volume configuration per component. Storage class defaults to the cluster default when empty."
  type = object({
    ingester = optional(object({
      enabled       = optional(bool, true)
      size          = optional(string, "100Gi")
      storage_class = optional(string, "")
      access_modes  = optional(list(string), ["ReadWriteOnce"])
    }), {})
    querier = optional(object({
      enabled       = optional(bool, true)
      size          = optional(string, "100Gi")
      storage_class = optional(string, "")
      access_modes  = optional(list(string), ["ReadWriteOnce"])
    }), {})
    alertmanager = optional(object({
      enabled       = optional(bool, true)
      size          = optional(string, "10Gi")
      storage_class = optional(string, "")
      access_modes  = optional(list(string), ["ReadWriteOnce"])
    }), {})
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Resources, scheduling
# ---------------------------------------------------------------------------

variable "resources" {
  description = <<-EOT
    CPU/memory resource requests and limits per component.
    Example:
      resources = {
        ingester = { requests = { memory = "2Gi", cpu = "500m" }, limits = { memory = "8Gi", cpu = "2000m" } }
        querier  = { requests = { memory = "2Gi", cpu = "500m" }, limits = { memory = "8Gi" } }
      }
  EOT
  type        = any
  default     = {}
}

variable "node_selector" {
  description = "Node selector labels per component. Keys follow the per-component pattern used by the chart (ingester, querier, router, compactor, alertmanager)."
  type = object({
    ingester     = optional(map(string), {})
    querier      = optional(map(string), {})
    router       = optional(map(string), {})
    compactor    = optional(map(string), {})
    alertmanager = optional(map(string), {})
  })
  default = {}
}

variable "tolerations" {
  description = "Pod tolerations per component. Each element is a Kubernetes toleration object."
  type = object({
    ingester     = optional(list(any), [])
    querier      = optional(list(any), [])
    router       = optional(list(any), [])
    compactor    = optional(list(any), [])
    alertmanager = optional(list(any), [])
  })
  default = {}
}

variable "affinity" {
  description = "Pod affinity/anti-affinity rules per component."
  type = object({
    ingester     = optional(any, {})
    querier      = optional(any, {})
    router       = optional(any, {})
    compactor    = optional(any, {})
    alertmanager = optional(any, {})
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Optional dependencies
# ---------------------------------------------------------------------------

variable "nats" {
  description = "NATS dependency bundled with the chart. Disable when using an external NATS cluster."
  type = object({
    enabled = optional(bool, true)
  })
  default = {}
}

variable "minio" {
  description = "MinIO dependency bundled with the chart. Disable when using AWS S3 or an external MinIO instance."
  type = object({
    enabled = optional(bool, false)
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Advanced overrides
# ---------------------------------------------------------------------------

variable "config" {
  description = <<-EOT
    Raw ZO_* environment variable overrides merged on top of module-managed config.
    Use for settings not exposed as first-class variables.
    Example: { "ZO_HTTP_WORKER_NUM" = "8", "ZO_QUERY_TIMEOUT" = "300" }
  EOT
  type        = map(string)
  default     = {}
}

variable "extra_values" {
  description = <<-EOT
    List of raw YAML value strings merged last (highest precedence).
    Use for helm chart sections not exposed as variables.
    Example: [<<-EOT
      enterprise:
        enabled: true
    EOT]
  EOT
  type        = list(string)
  default     = []
}
