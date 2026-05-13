# Native Terraform test (requires Terraform >= 1.7 for mock_provider).
# Run with: terraform test
#
# These tests use a mock Helm provider so no Kubernetes cluster is required.
# They validate that the module constructs correct Helm values from inputs.

mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "aws" {}

# -------------------------------------------------------------------------
# Default configuration
# -------------------------------------------------------------------------

variables {
  auth = {
    root_user_email    = "test@example.com"
    root_user_password = "TestPassword123!"
  }
  # Single-node mode for tests: no external dependencies
  meta_store          = "sqlite"
  cluster_coordinator = "local"
  queue_store         = "local"
  nats                = { enabled = false }
}

run "defaults_release_name_and_namespace" {
  command = plan

  assert {
    condition     = helm_release.this.name == "openobserve"
    error_message = "Default release name must be 'openobserve'."
  }

  assert {
    condition     = helm_release.this.namespace == "openobserve"
    error_message = "Default namespace must be 'openobserve'."
  }

  assert {
    condition     = helm_release.this.chart == "openobserve"
    error_message = "Chart name must be 'openobserve'."
  }

  assert {
    condition     = helm_release.this.repository == "https://charts.openobserve.ai"
    error_message = "Repository must point to the official OpenObserve chart repository."
  }
}

run "defaults_create_namespace_true" {
  command = plan

  assert {
    condition     = helm_release.this.create_namespace == true
    error_message = "create_namespace must default to true."
  }
}

# -------------------------------------------------------------------------
# Custom release name and namespace
# -------------------------------------------------------------------------

run "custom_release_name_and_namespace" {
  command = plan

  variables {
    release_name = "o2"
    namespace    = "monitoring"
  }

  assert {
    condition     = helm_release.this.name == "o2"
    error_message = "release_name must match the provided value."
  }

  assert {
    condition     = helm_release.this.namespace == "monitoring"
    error_message = "namespace must match the provided value."
  }
}

# -------------------------------------------------------------------------
# Chart version is pinned
# -------------------------------------------------------------------------

run "chart_version_pinned" {
  command = plan

  variables {
    chart_version = "0.80.3"
  }

  assert {
    condition     = helm_release.this.version == "0.80.3"
    error_message = "chart_version must be passed through to the Helm release."
  }
}

# -------------------------------------------------------------------------
# Ingress disabled by default
# -------------------------------------------------------------------------

run "ingress_disabled_by_default" {
  command = plan

  assert {
    condition     = !var.ingress.enabled
    error_message = "ingress must be disabled by default."
  }
}

# -------------------------------------------------------------------------
# NATS enabled by default
# -------------------------------------------------------------------------

run "nats_enabled_by_default" {
  command = plan

  variables {
    # Reset to defaults
    nats                = {}
    meta_store          = "postgres"
    cluster_coordinator = "nats"
    queue_store         = "nats"
  }

  assert {
    condition     = var.nats.enabled == true
    error_message = "NATS must be enabled by default."
  }
}

# -------------------------------------------------------------------------
# Validation: invalid release_name rejected
# -------------------------------------------------------------------------

run "invalid_release_name_rejected" {
  command = plan

  variables {
    release_name = "INVALID_NAME"
  }

  expect_failures = [var.release_name]
}

# -------------------------------------------------------------------------
# Validation: short password rejected
# -------------------------------------------------------------------------

run "short_password_rejected" {
  command = plan

  variables {
    auth = {
      root_user_email    = "test@example.com"
      root_user_password = "short"
    }
  }

  expect_failures = [var.auth]
}

# -------------------------------------------------------------------------
# Validation: ingress host required when ingress enabled
# -------------------------------------------------------------------------

run "ingress_without_host_rejected" {
  command = plan

  variables {
    ingress = {
      enabled = true
      host    = ""
    }
  }

  expect_failures = [var.ingress]
}
