data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)

  tags = merge(var.tags, {
    ManagedBy = "terraform-openobserve"
    Cluster   = var.cluster_name
  })
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 4)]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS to discover subnets
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  # Enable IRSA so OpenObserve pods can assume the S3 IAM role without static keys
  enable_irsa = true

  eks_managed_node_groups = {
    openobserve = {
      instance_types = [var.node_instance_type]
      ami_type       = can(regex("^[a-z][0-9]+g", var.node_instance_type)) ? "AL2023_ARM_64_STANDARD" : "AL2023_x86_64_STANDARD"

      min_size     = var.node_min_count
      max_size     = var.node_max_count
      desired_size = var.node_desired_count

      labels = {
        role = "openobserve"
      }

      taints = []

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }
    }
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# S3 bucket for OpenObserve data
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "openobserve" {
  bucket        = var.s3_bucket_name
  force_destroy = var.s3_force_destroy

  tags = local.tags
}

resource "aws_s3_bucket_versioning" "openobserve" {
  bucket = aws_s3_bucket.openobserve.id
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "openobserve" {
  bucket = aws_s3_bucket.openobserve.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "openobserve" {
  bucket                  = aws_s3_bucket.openobserve.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# IAM role for OpenObserve (IRSA — no static access keys needed)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "openobserve_s3" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.openobserve.arn]
  }

  statement {
    sid    = "ReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.openobserve.arn}/*"]
  }
}

resource "aws_iam_policy" "openobserve_s3" {
  name        = "${var.cluster_name}-openobserve-s3"
  description = "Allows OpenObserve pods to read and write the data bucket via IRSA."
  policy      = data.aws_iam_policy_document.openobserve_s3.json
  tags        = local.tags
}

module "openobserve_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-openobserve-irsa"

  role_policy_arns = {
    s3 = aws_iam_policy.openobserve_s3.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.kubernetes_namespace}:${var.openobserve_service_account}"]
    }
  }

  tags = local.tags
}
