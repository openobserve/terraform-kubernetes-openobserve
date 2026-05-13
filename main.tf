# ---------------------------------------------------------------------------
# AWS infrastructure (only when create_aws_infrastructure = true)
# ---------------------------------------------------------------------------

module "aws_infrastructure" {
  count  = var.create_aws_infrastructure ? 1 : 0
  source = "./modules/aws-infrastructure"

  cluster_name       = var.release_name
  region             = var.aws_config.region
  vpc_cidr           = var.aws_config.vpc_cidr
  availability_zones = var.aws_config.availability_zones
  s3_bucket_name     = var.aws_config.s3_bucket_name != "" ? var.aws_config.s3_bucket_name : "${var.release_name}-data"
  s3_force_destroy   = var.aws_config.s3_force_destroy
  tags               = var.aws_config.tags

  # Use capacity recommendations when aws_config doesn't override them
  node_instance_type = var.aws_config.node_instance_type != "" ? var.aws_config.node_instance_type : local.recommended_instance_type
  node_min_count     = var.aws_config.node_min_count
  node_max_count     = var.aws_config.node_max_count
  node_desired_count = var.aws_config.node_desired_count > 0 ? var.aws_config.node_desired_count : local.recommended_node_count

  kubernetes_namespace        = var.namespace
  openobserve_service_account = var.release_name
}

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
      ingester     = max(var.replica_count.ingester, local.recommended_replicas.ingester)
      querier      = max(var.replica_count.querier, local.recommended_replicas.querier)
      router       = max(var.replica_count.router, local.recommended_replicas.router)
      compactor    = max(var.replica_count.compactor, local.recommended_replicas.compactor)
      alertmanager = max(var.replica_count.alertmanager, local.recommended_replicas.alertmanager)
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

    # Module-managed ZO_* vars merged with caller overrides; caller wins.
    # When create_aws_infrastructure = true the S3 bucket/region come from
    # the aws_infrastructure submodule output and override var.s3.
    config = merge(
      {
        ZO_META_STORE                  = var.meta_store
        ZO_CLUSTER_COORDINATOR         = var.cluster_coordinator
        ZO_QUEUE_STORE                 = var.queue_store
        ZO_S3_PROVIDER                 = var.s3.provider
        ZO_S3_REGION_NAME              = var.create_aws_infrastructure ? module.aws_infrastructure[0].s3_bucket_region : var.s3.region
        ZO_S3_BUCKET_NAME              = var.create_aws_infrastructure ? module.aws_infrastructure[0].s3_bucket_name : var.s3.bucket_name
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

  # Module-computed values have lowest precedence; extra_values strings win.
  # When create_aws_infrastructure = true, append IRSA service account annotation.
  values = concat(
    [yamlencode(local.helm_values)],
    var.create_aws_infrastructure ? [yamlencode({
      serviceAccount = {
        create = true
        name   = var.release_name
        annotations = {
          "eks.amazonaws.com/role-arn" = module.aws_infrastructure[0].irsa_role_arn
        }
      }
    })] : [],
    var.extra_values
  )

  timeout         = var.timeout
  atomic          = var.atomic
  cleanup_on_fail = var.cleanup_on_fail
  wait            = var.wait
}
