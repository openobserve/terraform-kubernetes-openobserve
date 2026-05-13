variable "cluster_name" {
  description = "Name for the EKS cluster and associated resources."
  type        = string
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use. Defaults to the first three zones in the region."
  type        = list(string)
  default     = []
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes."
  type        = string
  default     = "m7g.2xlarge"
}

variable "node_min_count" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum number of worker nodes (for cluster autoscaler)."
  type        = number
  default     = 10
}

variable "node_desired_count" {
  description = "Initial desired number of worker nodes."
  type        = number
  default     = 3
}

variable "s3_bucket_name" {
  description = "Name for the S3 bucket used by OpenObserve for data storage."
  type        = string
}

variable "s3_force_destroy" {
  description = "Allow Terraform to delete the S3 bucket even when it contains data. Set false in production."
  type        = bool
  default     = false
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace where OpenObserve will be deployed. Used to scope the IRSA policy."
  type        = string
  default     = "openobserve"
}

variable "openobserve_service_account" {
  description = "Kubernetes service account name for OpenObserve. Used to bind the IRSA IAM role."
  type        = string
  default     = "openobserve"
}

variable "tags" {
  description = "Tags applied to all AWS resources."
  type        = map(string)
  default     = {}
}
