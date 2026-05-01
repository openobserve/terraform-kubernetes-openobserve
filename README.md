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

| Name | Version |
|------|---------|
| terraform | >= 1.9 |
| helm | ~> 2.16 |
| kubernetes | ~> 2.35 |

## Providers

| Name | Version |
|------|---------|
| helm | ~> 2.16 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| auth | Authentication credentials. root\_user\_email and root\_user\_password are required. | `object({...})` | n/a | yes |
| affinity | Pod affinity/anti-affinity rules per component. | `object({...})` | `{}` | no |
| atomic | Automatically roll back the release on install/upgrade failure. | `bool` | `false` | no |
| chart\_version | Version of the openobserve Helm chart. Pin this for reproducible deployments. | `string` | `"0.80.3"` | no |
| cleanup\_on\_fail | Delete newly created resources when an upgrade fails. | `bool` | `false` | no |
| cluster\_coordinator | Cluster coordination backend. `nats` is required for multi-node deployments. | `string` | `"nats"` | no |
| config | Raw ZO\_\* environment variable overrides merged on top of module-managed config. | `map(string)` | `{}` | no |
| create\_namespace | Create the Kubernetes namespace if it does not exist. | `bool` | `true` | no |
| data\_retention\_days | Days to retain data before compaction removes it. | `number` | `3650` | no |
| extra\_values | List of raw YAML value strings merged last (highest precedence). | `list(string)` | `[]` | no |
| image | Container image configuration. | `object({...})` | `{}` | no |
| image\_pull\_secrets | List of Kubernetes Secret names used to pull the container image. | `list(string)` | `[]` | no |
| ingress | Ingress configuration. | `object({...})` | `{}` | no |
| meta\_store | Metadata storage backend. Use `postgres` for all HA deployments. | `string` | `"postgres"` | no |
| minio | MinIO dependency bundled with the chart. | `object({...})` | `{}` | no |
| namespace | Kubernetes namespace to deploy OpenObserve into. | `string` | `"openobserve"` | no |
| nats | NATS dependency bundled with the chart. | `object({...})` | `{}` | no |
| node\_selector | Node selector labels per component. | `object({...})` | `{}` | no |
| persistence | Persistent volume configuration per component. | `object({...})` | `{}` | no |
| queue\_store | Distributed queue backend. | `string` | `"nats"` | no |
| release\_name | Name of the Helm release. | `string` | `"openobserve"` | no |
| replica\_count | Number of replicas per component. | `object({...})` | `{}` | no |
| resources | CPU/memory resource requests and limits per component. | `any` | `{}` | no |
| s3 | S3-compatible object storage configuration. | `object({...})` | `{}` | no |
| service | Kubernetes Service configuration for the router component. | `object({...})` | `{}` | no |
| timeout | Timeout in seconds for Helm install/upgrade operations. | `number` | `600` | no |
| tolerations | Pod tolerations per component. | `object({...})` | `{}` | no |
| wait | Wait for all pods and services to be ready. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| app\_version | Application version reported by the Helm chart metadata. |
| chart\_version | Version of the deployed Helm chart. |
| grpc\_endpoint | In-cluster gRPC endpoint used by OpenTelemetry exporters. |
| http\_endpoint | In-cluster HTTP endpoint for the OpenObserve UI and ingestion API. |
| ingress\_host | Ingress hostname, or empty string when ingress is disabled. |
| namespace | Kubernetes namespace where OpenObserve is deployed. |
| release\_name | Name of the deployed Helm release. |
| service\_name | Kubernetes Service name for the OpenObserve router. |
| status | Current Helm release status. |
<!-- END_TF_DOCS -->

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache 2.0 — see [LICENSE](LICENSE).
