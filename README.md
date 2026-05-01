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
<!-- END_TF_DOCS -->

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache 2.0 — see [LICENSE](LICENSE).
