# terraform-kubernetes-openobserve

Terraform module for deploying [OpenObserve](https://openobserve.ai) on Kubernetes using the official Helm chart.

OpenObserve is a cloud-native observability platform for logs, metrics, traces, dashboards, RUM, error tracking, and session replay — with Elasticsearch API compatibility.

**Helm chart**: [openobserve/openobserve-helm-chart](https://github.com/openobserve/openobserve-helm-chart/tree/main/charts/openobserve) `v0.80.3`

---

## Usage

### Minimal (development / single-node)

```hcl
module "openobserve" {
  source  = "openobserve/openobserve/kubernetes"
  version = "~> 1.0"

  auth = {
    root_user_email    = "admin@example.com"
    root_user_password = "ChangeMe123!"
  }

  # Single-node local mode: no PostgreSQL or NATS required
  meta_store          = "sqlite"
  cluster_coordinator = "local"
  queue_store         = "local"
  nats                = { enabled = false }
}
```

Access the UI:
```bash
kubectl port-forward -n openobserve svc/openobserve-router 5080:5080
# Open http://localhost:5080
```

### Production HA (PostgreSQL + NATS + S3)

```hcl
module "openobserve" {
  source  = "openobserve/openobserve/kubernetes"
  version = "~> 1.0"

  auth = {
    root_user_email    = var.root_user_email
    root_user_password = var.root_user_password
    postgres_dsn       = var.postgres_dsn
    s3_access_key      = var.s3_access_key   # omit to use IRSA
    s3_secret_key      = var.s3_secret_key
  }

  replica_count = {
    ingester     = 3
    querier      = 2
    router       = 2
    compactor    = 1
    alertmanager = 1
  }

  meta_store          = "postgres"
  cluster_coordinator = "nats"
  queue_store         = "nats"

  s3 = {
    provider    = "s3"
    region      = "us-east-1"
    bucket_name = "my-openobserve-data"
  }

  ingress = {
    enabled         = true
    class_name      = "nginx"
    host            = "openobserve.example.com"
    tls_secret_name = "openobserve-tls"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  persistence = {
    ingester     = { size = "100Gi", storage_class = "gp3" }
    querier      = { size = "100Gi", storage_class = "gp3" }
    alertmanager = { size = "10Gi",  storage_class = "gp3" }
  }

  resources = {
    ingester = {
      requests = { memory = "2Gi", cpu = "500m" }
      limits   = { memory = "8Gi", cpu = "2000m" }
    }
    querier = {
      requests = { memory = "2Gi", cpu = "500m" }
      limits   = { memory = "8Gi", cpu = "2000m" }
    }
  }

  nats  = { enabled = true }
  minio = { enabled = false }
}
```

### Enterprise edition

```hcl
module "openobserve" {
  source  = "openobserve/openobserve/kubernetes"
  version = "~> 1.0"

  image = {
    repository = "o2cr.ai/openobserve/openobserve-enterprise"
    tag        = "v0.80.2"
  }

  # ... rest of your configuration
}
```

### Passing arbitrary Helm values

Any setting not exposed as a first-class variable can be passed through `extra_values` (highest precedence):

```hcl
module "openobserve" {
  source  = "openobserve/openobserve/kubernetes"
  version = "~> 1.0"

  # ... required variables

  extra_values = [<<-EOT
    enterprise:
      enabled: true
    config:
      ZO_SWAGGER_ENABLED: "true"
      ZO_PROMETHEUS_ENABLED: "true"
  EOT
  ]
}
```

---

## Examples

| Example | Description |
|---------|-------------|
| [examples/minimal](examples/minimal) | Single-node SQLite deployment for development |
| [examples/complete](examples/complete) | Production HA: PostgreSQL + NATS + S3 + Ingress + TLS |

---

## Terraform Registry

This module is published at:

```
registry.terraform.io/modules/openobserve/openobserve/kubernetes
```

---

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Terraform | `>= 1.9` | `optional()` with defaults requires 1.3+; mock provider tests require 1.7+ |
| hashicorp/helm provider | `~> 2.16` | |
| Kubernetes cluster | `>= 1.25` | EKS, GKE, AKS, or self-managed |
| Default StorageClass | — | Required for persistent volumes |
| PostgreSQL | `>= 14` | Required for `meta_store = "postgres"` (HA) |
| S3-compatible bucket | — | Required for production data persistence |

---

## Architecture

```
                     ┌─────────────────────────────────────────────┐
                     │              Kubernetes Cluster              │
                     │                                              │
  Ingest / Query ───►│  router (stateless, horizontally scalable)  │
                     │      │              │                        │
                     │  ingester ◄────► querier                    │
                     │  (WAL + disk)   (disk cache)                 │
                     │      │              │                        │
                     │  compactor      alertmanager                 │
                     │      │                                        │
                     │  NATS (bundled or external)                  │
                     │      │                                        │
                     └──────┼─────────────────────────────────────-─┘
                            │
                ┌───────────┼──────────────┐
                │           │              │
           PostgreSQL       S3          Object Store
          (metadata)   (long-term data)
```

---

## Upgrading the chart version

1. Check the [OpenObserve Helm chart releases](https://github.com/openobserve/openobserve-helm-chart/releases) for breaking changes.
2. Update `chart_version` in your module call.
3. Run `terraform plan` and review the diff before applying.
4. For major chart version bumps, run `terraform apply` during a maintenance window.

---

<!-- BEGIN_TF_DOCS -->
## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement_aws) | ~> 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement_helm) | ~> 2.16 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement_kubernetes) | ~> 2.35 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider_helm) | ~> 2.16 |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_affinity"></a> [affinity](#input_affinity) | Pod affinity/anti-affinity rules per component. | <pre>object({<br/>    ingester     = optional(any, {})<br/>    querier      = optional(any, {})<br/>    router       = optional(any, {})<br/>    compactor    = optional(any, {})<br/>    alertmanager = optional(any, {})<br/>  })</pre> | `{}` | no |
| <a name="input_atomic"></a> [atomic](#input_atomic) | Automatically roll back the release on install/upgrade failure. | `bool` | `false` | no |
| <a name="input_auth"></a> [auth](#input_auth) | Authentication credentials. All values are stored in a Kubernetes Secret.<br/>root_user_email and root_user_password are required.<br/>Provide s3_access_key / s3_secret_key for AWS-signature S3 auth.<br/>Provide postgres_dsn for PostgreSQL metadata store. | <pre>object({<br/>    root_user_email    = string<br/>    root_user_password = string<br/>    root_user_token    = optional(string, "")<br/>    s3_access_key      = optional(string, "")<br/>    s3_secret_key      = optional(string, "")<br/>    postgres_dsn       = optional(string, "")<br/>    postgres_ro_dsn    = optional(string, "")<br/>  })</pre> | n/a | yes |
| <a name="input_aws_config"></a> [aws_config](#input_aws_config) | AWS infrastructure settings. Only used when create_aws_infrastructure = true. | <pre>object({<br/>    region             = optional(string, "us-east-1")<br/>    vpc_cidr           = optional(string, "10.0.0.0/16")<br/>    availability_zones = optional(list(string), [])<br/>    node_instance_type = optional(string, "") # defaults to capacity recommendation<br/>    node_min_count     = optional(number, 2)<br/>    node_max_count     = optional(number, 10)<br/>    node_desired_count = optional(number, 0) # defaults to capacity recommendation<br/>    s3_bucket_name     = optional(string, "")<br/>    s3_force_destroy   = optional(bool, false)<br/>    tags               = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_capacity"></a> [capacity](#input_capacity) | Capacity planning inputs. When set, the module computes and outputs:<br/>- recommended deployment mode (single-node vs HA)<br/>- recommended replica counts per component<br/>- recommended EKS instance type and node count<br/>- S3 storage estimate<br/>- estimated monthly cost<br/><br/>These are informational outputs only; set replica_count explicitly to<br/>override the recommendations. When create_aws_infrastructure = true,<br/>the recommendations are used as defaults for aws_config if not overridden.<br/><br/>Reference data (256 GB/day):<br/>  Single-node: 5 cores, ~$179/month<br/>  HA:         25 cores, ~$927/month | <pre>object({<br/>    ingestion_gb_per_day = optional(number, 0)<br/>    data_retention_days  = optional(number, 30)<br/>    compression_ratio    = optional(number, 0.9)<br/>  })</pre> | `{}` | no |
| <a name="input_chart_version"></a> [chart_version](#input_chart_version) | Version of the openobserve Helm chart. Pin this for reproducible deployments. | `string` | `"0.80.3"` | no |
| <a name="input_cleanup_on_fail"></a> [cleanup_on_fail](#input_cleanup_on_fail) | Delete newly created resources when an upgrade fails. | `bool` | `false` | no |
| <a name="input_cluster_coordinator"></a> [cluster_coordinator](#input_cluster_coordinator) | Cluster coordination backend. 'nats' is required for multi-node deployments. | `string` | `"nats"` | no |
| <a name="input_config"></a> [config](#input_config) | Raw ZO_* environment variable overrides merged on top of module-managed config.<br/>Use for settings not exposed as first-class variables.<br/>Example: { "ZO_HTTP_WORKER_NUM" = "8", "ZO_QUERY_TIMEOUT" = "300" } | `map(string)` | `{}` | no |
| <a name="input_create_aws_infrastructure"></a> [create_aws_infrastructure](#input_create_aws_infrastructure) | When true, the module creates a complete AWS environment (VPC, EKS cluster,<br/>S3 bucket, IAM role with IRSA) before deploying OpenObserve into it.<br/>When false (default), OpenObserve is deployed into your existing cluster;<br/>the aws_config block is ignored and no AWS resources are created. | `bool` | `false` | no |
| <a name="input_create_namespace"></a> [create_namespace](#input_create_namespace) | Create the Kubernetes namespace if it does not exist. | `bool` | `true` | no |
| <a name="input_data_retention_days"></a> [data_retention_days](#input_data_retention_days) | Days to retain data before compaction removes it (ZO_COMPACT_DATA_RETENTION_DAYS). | `number` | `3650` | no |
| <a name="input_extra_values"></a> [extra_values](#input_extra_values) | List of raw YAML value strings merged last (highest precedence).<br/>Use for helm chart sections not exposed as variables.<br/>Example: [<<-EOT<br/>  enterprise:<br/>    enabled: true<br/>EOT] | `list(string)` | `[]` | no |
| <a name="input_image"></a> [image](#input_image) | Container image configuration.<br/>Set repository to 'o2cr.ai/openobserve/openobserve-enterprise' for the enterprise edition.<br/>Leave tag empty to use the chart's default version. | <pre>object({<br/>    repository  = optional(string, "o2cr.ai/openobserve/openobserve")<br/>    tag         = optional(string, "")<br/>    pull_policy = optional(string, "IfNotPresent")<br/>  })</pre> | `{}` | no |
| <a name="input_image_pull_secrets"></a> [image_pull_secrets](#input_image_pull_secrets) | List of Kubernetes Secret names used to pull the container image. | `list(string)` | `[]` | no |
| <a name="input_ingress"></a> [ingress](#input_ingress) | Ingress configuration. Enable to expose OpenObserve externally.<br/>Requires an Ingress controller (e.g. nginx-ingress) in the cluster.<br/>Set tls_secret_name to enable HTTPS with cert-manager. | <pre>object({<br/>    enabled         = optional(bool, false)<br/>    class_name      = optional(string, "nginx")<br/>    host            = optional(string, "")<br/>    annotations     = optional(map(string), {})<br/>    tls_secret_name = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_meta_store"></a> [meta_store](#input_meta_store) | Metadata storage backend. Use 'postgres' for all HA deployments. | `string` | `"postgres"` | no |
| <a name="input_minio"></a> [minio](#input_minio) | MinIO dependency bundled with the chart. Disable when using AWS S3 or an external MinIO instance. | <pre>object({<br/>    enabled = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input_namespace) | Kubernetes namespace to deploy OpenObserve into. | `string` | `"openobserve"` | no |
| <a name="input_nats"></a> [nats](#input_nats) | NATS dependency bundled with the chart. Disable when using an external NATS cluster. | <pre>object({<br/>    enabled = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_node_selector"></a> [node_selector](#input_node_selector) | Node selector labels per component. Keys follow the per-component pattern used by the chart (ingester, querier, router, compactor, alertmanager). | <pre>object({<br/>    ingester     = optional(map(string), {})<br/>    querier      = optional(map(string), {})<br/>    router       = optional(map(string), {})<br/>    compactor    = optional(map(string), {})<br/>    alertmanager = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_persistence"></a> [persistence](#input_persistence) | Persistent volume configuration per component. Storage class defaults to the cluster default when empty. | <pre>object({<br/>    ingester = optional(object({<br/>      enabled       = optional(bool, true)<br/>      size          = optional(string, "100Gi")<br/>      storage_class = optional(string, "")<br/>      access_modes  = optional(list(string), ["ReadWriteOnce"])<br/>    }), {})<br/>    querier = optional(object({<br/>      enabled       = optional(bool, true)<br/>      size          = optional(string, "100Gi")<br/>      storage_class = optional(string, "")<br/>      access_modes  = optional(list(string), ["ReadWriteOnce"])<br/>    }), {})<br/>    alertmanager = optional(object({<br/>      enabled       = optional(bool, true)<br/>      size          = optional(string, "10Gi")<br/>      storage_class = optional(string, "")<br/>      access_modes  = optional(list(string), ["ReadWriteOnce"])<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_queue_store"></a> [queue_store](#input_queue_store) | Distributed queue backend. 'nats' is required for multi-node deployments. | `string` | `"nats"` | no |
| <a name="input_release_name"></a> [release_name](#input_release_name) | Name of the Helm release. | `string` | `"openobserve"` | no |
| <a name="input_replica_count"></a> [replica_count](#input_replica_count) | Number of replicas per component. Increase querier/ingester for HA; router is stateless and scales horizontally. | <pre>object({<br/>    ingester     = optional(number, 1)<br/>    querier      = optional(number, 1)<br/>    router       = optional(number, 1)<br/>    compactor    = optional(number, 1)<br/>    alertmanager = optional(number, 1)<br/>  })</pre> | `{}` | no |
| <a name="input_resources"></a> [resources](#input_resources) | CPU/memory resource requests and limits per component.<br/>Example:<br/>  resources = {<br/>    ingester = { requests = { memory = "2Gi", cpu = "500m" }, limits = { memory = "8Gi", cpu = "2000m" } }<br/>    querier  = { requests = { memory = "2Gi", cpu = "500m" }, limits = { memory = "8Gi" } }<br/>  } | `any` | `{}` | no |
| <a name="input_s3"></a> [s3](#input_s3) | S3-compatible object storage configuration.<br/>OpenObserve uses S3 for long-term data persistence.<br/>Set server_url to use MinIO or other S3-compatible providers. | <pre>object({<br/>    provider      = optional(string, "s3")<br/>    region        = optional(string, "us-east-1")<br/>    bucket_name   = optional(string, "")<br/>    server_url    = optional(string, "")<br/>    bucket_prefix = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_service"></a> [service](#input_service) | Kubernetes Service configuration for the router component. | <pre>object({<br/>    type      = optional(string, "ClusterIP")<br/>    http_port = optional(number, 5080)<br/>    grpc_port = optional(number, 5081)<br/>  })</pre> | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input_timeout) | Timeout in seconds for Helm install/upgrade operations. | `number` | `600` | no |
| <a name="input_tolerations"></a> [tolerations](#input_tolerations) | Pod tolerations per component. Each element is a Kubernetes toleration object. | <pre>object({<br/>    ingester     = optional(list(any), [])<br/>    querier      = optional(list(any), [])<br/>    router       = optional(list(any), [])<br/>    compactor    = optional(list(any), [])<br/>    alertmanager = optional(list(any), [])<br/>  })</pre> | `{}` | no |
| <a name="input_wait"></a> [wait](#input_wait) | Wait for all pods and services to be ready before marking the release as successful. | `bool` | `true` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_version"></a> [app_version](#output_app_version) | Application version reported by the Helm chart metadata. |
| <a name="output_aws_infrastructure"></a> [aws_infrastructure](#output_aws_infrastructure) | AWS resource details created by the module. Null when create_aws_infrastructure = false. |
| <a name="output_capacity_recommendations"></a> [capacity_recommendations](#output_capacity_recommendations) | Capacity planning recommendations derived from your ingestion_gb_per_day input.<br/>Use these to right-size replicas, EKS nodes, and plan AWS spend before applying.<br/>Set capacity.ingestion_gb_per_day to enable. |
| <a name="output_chart_version"></a> [chart_version](#output_chart_version) | Version of the deployed Helm chart. |
| <a name="output_grpc_endpoint"></a> [grpc_endpoint](#output_grpc_endpoint) | In-cluster gRPC endpoint used by OpenTelemetry exporters. |
| <a name="output_http_endpoint"></a> [http_endpoint](#output_http_endpoint) | In-cluster HTTP endpoint for the OpenObserve UI and ingestion API. |
| <a name="output_ingress_host"></a> [ingress_host](#output_ingress_host) | Ingress hostname, or empty string when ingress is disabled. |
| <a name="output_namespace"></a> [namespace](#output_namespace) | Kubernetes namespace where OpenObserve is deployed. |
| <a name="output_release_name"></a> [release_name](#output_release_name) | Name of the deployed Helm release. |
| <a name="output_service_name"></a> [service_name](#output_service_name) | Kubernetes Service name for the OpenObserve router (entry point for all traffic). |
| <a name="output_status"></a> [status](#output_status) | Current Helm release status (e.g. deployed, failed). |
<!-- END_TF_DOCS -->

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache 2.0 — see [LICENSE](LICENSE).
