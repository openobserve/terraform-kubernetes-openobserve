locals {
  # ---------------------------------------------------------------------------
  # Capacity planning
  # Reference: 30 TB/Day HA deployment (30,720 GB/day)
  #
  # Component cores at reference point:
  #   Ingester:        124  (r7g.medium  @ $0.0536/hr/core)
  #   Querier (3x):    372  (r7gd.medium @ $0.0680/hr/core, 3× ingester for light analytics)
  #   Compactor:        31
  #   Other (router + alertmanager + report + nats + misc): ~20
  #   Total:           547 cores
  #
  # Querier multipliers by workload:
  #   Search / light analytics: 3×
  #   Medium analytics:         5×
  #   Heavy analytics:          10×
  #
  # Cost reference at 30 TB/day:
  #   Compute:    $26,001/month
  #   S3 storage: $3,180/month
  #   RDS:        $2,136/month
  #   NLB:        $5,531/month
  #   Total:      $36,847/month  ($0.040/GB/month on-demand)
  # ---------------------------------------------------------------------------

  cap_enabled = var.capacity.ingestion_gb_per_day > 0

  # Recommended deployment mode: single-node up to 500 GB/day, HA above
  recommended_mode = local.cap_enabled ? (
    var.capacity.ingestion_gb_per_day > 500 ? "highly-available" : "single-node"
  ) : "not-computed"

  # S3 data at rest: ingestion × (1 − compression) × retention
  _kept_ratio   = 1 - var.capacity.compression_ratio
  s3_storage_gb = local.cap_enabled ? ceil(var.capacity.ingestion_gb_per_day * local._kept_ratio * var.capacity.data_retention_days) : 0

  # ---------------------------------------------------------------------------
  # Core requirements (scaled from 30,720 GB/day reference)
  # ---------------------------------------------------------------------------
  _ingester_cores  = local.cap_enabled ? ceil(var.capacity.ingestion_gb_per_day * 124.0 / 30720) : 1
  _querier_cores   = local.cap_enabled ? ceil(var.capacity.ingestion_gb_per_day * 372.0 / 30720) : 1
  _compactor_cores = local.cap_enabled ? ceil(var.capacity.ingestion_gb_per_day * 31.0 / 30720) : 1
  _other_cores     = local.cap_enabled ? ceil(var.capacity.ingestion_gb_per_day * 20.0 / 30720) : 1
  total_cpu_cores  = local._ingester_cores + local._querier_cores + local._compactor_cores + local._other_cores

  # ---------------------------------------------------------------------------
  # Replica counts (1 pod ≈ 1 core for r7g.medium baseline)
  # ---------------------------------------------------------------------------
  recommended_replicas = {
    ingester     = max(2, local._ingester_cores)
    querier      = max(1, local._querier_cores)
    compactor    = max(1, local._compactor_cores)
    router       = max(2, local.cap_enabled ? ceil(var.capacity.ingestion_gb_per_day * 2.48 / 30720) : 1)
    alertmanager = max(1, local.cap_enabled ? ceil(var.capacity.ingestion_gb_per_day * 2.48 / 30720) : 1)
  }

  # ---------------------------------------------------------------------------
  # EKS node recommendation
  # r7g (Graviton3 memory-optimised) is the cost-effective baseline.
  # r7gd (with local NVMe) is preferred for queriers in large deployments.
  # ---------------------------------------------------------------------------
  recommended_instance_type = (
    local.total_cpu_cores <= 8 ? "r7g.2xlarge" :
    local.total_cpu_cores <= 32 ? "r7g.4xlarge" :
    local.total_cpu_cores <= 128 ? "r7g.8xlarge" : "r7g.16xlarge"
  )
  _instance_cores = {
    "r7g.2xlarge"  = 8
    "r7g.4xlarge"  = 16
    "r7g.8xlarge"  = 32
    "r7g.16xlarge" = 64
  }
  # Minimum 3 nodes (one per AZ) + 1 spare
  recommended_node_count = local.cap_enabled ? max(
    3,
    ceil(local.total_cpu_cores / lookup(local._instance_cores, local.recommended_instance_type, 8)) + 1
  ) : 3

  # ---------------------------------------------------------------------------
  # RDS cost lookup (from capacity reference table, indexed by TB/day)
  # ---------------------------------------------------------------------------
  _ingestion_tb_per_day = local.cap_enabled ? ceil(var.capacity.ingestion_gb_per_day / 1024) : 1
  _rds_cost = (
    local._ingestion_tb_per_day <= 4 ? 356 :
    local._ingestion_tb_per_day <= 8 ? 534 :
    local._ingestion_tb_per_day <= 16 ? 1068 :
    local._ingestion_tb_per_day <= 32 ? 2136 :
    local._ingestion_tb_per_day <= 64 ? 4271 :
    local._ingestion_tb_per_day <= 128 ? 8542 :
    local._ingestion_tb_per_day <= 256 ? 17084 :
    local._ingestion_tb_per_day <= 512 ? 34168 : 68336
  )

  # ---------------------------------------------------------------------------
  # Monthly cost estimates
  # Compute: r7g  @ $0.0536/hr/core × 730 hr = $39.13/core/month
  #          r7gd @ $0.0680/hr/core × 730 hr = $49.64/core/month
  # S3:      $0.023/GB/month + ~50% for requests
  # NLB:     scaled from $5,531/month at 30 TB/day
  # ---------------------------------------------------------------------------
  _ingester_cost   = ceil(local._ingester_cores * 39)
  _querier_cost    = ceil(local._querier_cores * 50)
  _other_cost      = ceil(local._other_cores * 39)
  _s3_storage_cost = ceil(local.s3_storage_gb * 23 / 1000)
  _s3_request_cost = ceil(local._s3_storage_cost / 2)
  _nlb_cost        = local.cap_enabled ? max(46, ceil(var.capacity.ingestion_gb_per_day * 5531 / 30720)) : 46
  _eks_cost        = 80

  estimated_monthly_cost_usd = local.cap_enabled ? (
    local._ingester_cost + local._querier_cost + local._other_cost +
    local._s3_storage_cost + local._s3_request_cost +
    local._rds_cost + local._nlb_cost + local._eks_cost
  ) : 0

  # $/GB ingested — useful for customer proposals
  # = monthly_cost / (ingestion_gb_per_day × 30)
  estimated_price_per_gb_ingested = (local.cap_enabled && var.capacity.ingestion_gb_per_day > 0) ? (
    local.estimated_monthly_cost_usd / (var.capacity.ingestion_gb_per_day * 30)
  ) : 0
}
