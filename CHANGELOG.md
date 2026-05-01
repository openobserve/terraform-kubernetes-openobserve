# Changelog

All notable changes to this module are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)  
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)  
Releases: automated from [Conventional Commits](https://www.conventionalcommits.org/) via release-please.

---

<!-- Release notes below this line are managed automatically by release-please -->

## [0.0.2](https://github.com/openobserve/terraform-kubernetes-openobserve/compare/v0.0.1...v0.0.2) (2026-05-01)


### Bug Fixes

* resolve all CI failures ([8ee9983](https://github.com/openobserve/terraform-kubernetes-openobserve/commit/8ee99838a29974524145ecc6be138ee8ff716ae6))

## [0.0.1] - 2026-04-30

### 🚀 Initial Release

First public release of the official OpenObserve Terraform module for Kubernetes.

This module wraps the [OpenObserve Helm chart](https://github.com/openobserve/openobserve-helm-chart)
(`charts/openobserve` `v0.80.3`, app `v0.80.2`) and publishes it to the
[Terraform Registry](https://registry.terraform.io/modules/openobserve/openobserve/kubernetes)
as `openobserve/openobserve/kubernetes`.

### Added

**Module core**

- `helm_release` wrapper using `yamlencode` for clean, mergeable Helm values
- First-class variables for all commonly configured settings:
  - `auth` — root credentials, S3 keys, PostgreSQL DSN (all `sensitive = true`, stored in a Kubernetes Secret by the chart)
  - `replica_count` — per-component replica counts (ingester, querier, router, compactor, alertmanager)
  - `image` — repository, tag, pull policy; switch to enterprise image by changing `repository`
  - `meta_store` / `cluster_coordinator` / `queue_store` — backend selection
  - `s3` — bucket, region, provider, server URL for S3-compatible stores
  - `ingress` — nginx class, host, TLS secret, annotations
  - `persistence` — per-component PVC size, storage class, access modes
  - `resources` — CPU/memory requests and limits per component
  - `node_selector`, `tolerations`, `affinity` — per-component scheduling
  - `nats` / `minio` — enable or disable bundled dependencies
  - `config` — raw `ZO_*` env var overrides merged on top of module defaults
  - `extra_values` — raw YAML strings with highest override precedence (escape hatch)

**Examples**

- [`examples/minimal`](examples/minimal) — single-node SQLite deployment; no PostgreSQL or NATS required; suitable for development and evaluation
- [`examples/complete`](examples/complete) — production HA deployment: 3 ingesters, 2 queriers, PostgreSQL metadata store, bundled NATS, AWS S3, nginx Ingress with cert-manager TLS, per-component resource limits and pod anti-affinity

**Tests**

- 9 native Terraform tests (`terraform test`) using mock providers — no Kubernetes cluster required
- Covers: default values, custom namespace/release name, chart version pinning, NATS defaults, and validation failures (invalid release name, short password, missing ingress host)

**CI / CD**

- `ci.yml` — 6-job pipeline on every PR and push to `main`:
  - `fmt` — `terraform fmt -check -recursive`
  - `validate` — matrix across root module + both examples
  - `lint` — TFLint with terraform recommended ruleset
  - `security` — Trivy (CRITICAL/HIGH exit-1) + Checkov (soft-fail)
  - `test` — `terraform test` with mock providers
  - `docs` — terraform-docs inject check (README must stay in sync)
- `release.yml` — release-please automation: detects conventional commits, opens Release PR, creates `vX.Y.Z` tag on merge; post-release validate + annotate

**Repository hygiene**

- `.tflint.hcl` — enforces snake_case naming, typed variables, documented variables/outputs, required_providers
- `.terraform-docs.yml` — inject mode targeting `README.md`
- `release-please-config.json` — changelog sections, pre-major minor bumps
- `CONTRIBUTING.md` — local dev workflow, commit format guide, branch protection checklist
- Apache 2.0 License

### Requirements

| Component | Version |
|-----------|---------|
| Terraform | `>= 1.9` |
| hashicorp/helm | `~> 2.16` |
| hashicorp/kubernetes | `~> 2.35` |
| Kubernetes cluster | `>= 1.25` |

---

[0.0.1]: https://github.com/openobserve/terraform-kubernetes-openobserve/releases/tag/v0.0.1
