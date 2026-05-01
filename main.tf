locals {
  # Omit tag when empty so the chart's pinned default is preserved
  image_config = merge(
    { repository = var.image.repository },
    var.image.tag != "" ? { tag = var.image.tag } : {}
  )

  helm_values = {
    image = {
      oss        = local.image_config
      pullPolicy = var.image.pull_policy
    }

    imagePullSecrets = [for s in var.image_pull_secrets : { name = s }]

    replicaCount = {
      ingester     = var.replica_count.ingester
      querier      = var.replica_count.querier
      router       = var.replica_count.router
      compactor    = var.replica_count.compactor
      alertmanager = var.replica_count.alertmanager
    }

    # Credentials land in a Kubernetes Secret; never stored in ConfigMap
    auth = {
      ZO_ROOT_USER_EMAIL      = var.auth.root_user_email
      ZO_ROOT_USER_PASSWORD   = var.auth.root_user_password
      ZO_ROOT_USER_TOKEN      = var.auth.root_user_token
      ZO_S3_ACCESS_KEY        = var.auth.s3_access_key
      ZO_S3_SECRET_KEY        = var.auth.s3_secret_key
      ZO_META_POSTGRES_DSN    = var.auth.postgres_dsn
      ZO_META_POSTGRES_RO_DSN = var.auth.postgres_ro_dsn
    }

    # Module-managed ZO_* vars merged with caller overrides; caller wins
    config = merge(
      {
        ZO_META_STORE                  = var.meta_store
        ZO_CLUSTER_COORDINATOR         = var.cluster_coordinator
        ZO_QUEUE_STORE                 = var.queue_store
        ZO_S3_PROVIDER                 = var.s3.provider
        ZO_S3_REGION_NAME              = var.s3.region
        ZO_S3_BUCKET_NAME              = var.s3.bucket_name
        ZO_S3_SERVER_URL               = var.s3.server_url
        ZO_S3_BUCKET_PREFIX            = var.s3.bucket_prefix
        ZO_COMPACT_DATA_RETENTION_DAYS = tostring(var.data_retention_days)
      },
      var.config
    )

    service = {
      type      = var.service.type
      http_port = var.service.http_port
      grpc_port = var.service.grpc_port
    }

    ingress = {
      enabled   = var.ingress.enabled
      className = var.ingress.class_name
      annotations = merge(
        var.ingress.enabled ? {
          "nginx.ingress.kubernetes.io/enable-cors"        = "true"
          "nginx.ingress.kubernetes.io/proxy-http-version" = "1.1"
          "nginx.ingress.kubernetes.io/enable-websocket"   = "true"
        } : {},
        var.ingress.annotations
      )
      hosts = var.ingress.host != "" ? [
        {
          host  = var.ingress.host
          paths = [{ path = "/", pathType = "ImplementationSpecific" }]
        }
      ] : []
      tls = var.ingress.tls_secret_name != "" ? [
        {
          secretName = var.ingress.tls_secret_name
          hosts      = [var.ingress.host]
        }
      ] : []
    }

    ingester = {
      persistence = {
        enabled      = var.persistence.ingester.enabled
        size         = var.persistence.ingester.size
        storageClass = var.persistence.ingester.storage_class
        accessModes  = var.persistence.ingester.access_modes
      }
    }

    querier = {
      persistence = {
        enabled      = var.persistence.querier.enabled
        size         = var.persistence.querier.size
        storageClass = var.persistence.querier.storage_class
        accessModes  = var.persistence.querier.access_modes
      }
    }

    alertmanager = {
      persistence = {
        enabled      = var.persistence.alertmanager.enabled
        size         = var.persistence.alertmanager.size
        storageClass = var.persistence.alertmanager.storage_class
        accessModes  = var.persistence.alertmanager.access_modes
      }
    }

    resources    = var.resources
    nodeSelector = var.node_selector
    tolerations  = var.tolerations
    affinity     = var.affinity

    nats  = { enabled = var.nats.enabled }
    minio = { enabled = var.minio.enabled }
  }
}

resource "helm_release" "this" {
  name             = var.release_name
  namespace        = var.namespace
  create_namespace = var.create_namespace

  repository = "https://charts.openobserve.ai"
  chart      = "openobserve"
  version    = var.chart_version

  # Module-computed values have lowest precedence; extra_values strings win
  values = concat(
    [yamlencode(local.helm_values)],
    var.extra_values
  )

  timeout         = var.timeout
  atomic          = var.atomic
  cleanup_on_fail = var.cleanup_on_fail
  wait            = var.wait
}
