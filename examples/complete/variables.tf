variable "kubeconfig_path" {
  description = "Path to the kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "kubeconfig context to use. Defaults to current context when empty."
  type        = string
  default     = ""
}

variable "root_user_email" {
  description = "Email address for the initial OpenObserve admin user."
  type        = string
  sensitive   = true
}

variable "root_user_password" {
  description = "Password for the initial OpenObserve admin user (minimum 8 characters)."
  type        = string
  sensitive   = true
}

variable "postgres_dsn" {
  description = "PostgreSQL DSN for the OpenObserve metadata store. Format: postgres://user:password@host:5432/dbname"
  type        = string
  sensitive   = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name for OpenObserve object storage."
  type        = string
}

variable "s3_region" {
  description = "AWS region where the S3 bucket resides."
  type        = string
  default     = "us-east-1"
}

variable "s3_access_key" {
  description = "AWS Access Key ID for S3 authentication. Leave empty to use IRSA/instance profiles."
  type        = string
  default     = ""
  sensitive   = true
}

variable "s3_secret_key" {
  description = "AWS Secret Access Key for S3 authentication. Leave empty to use IRSA/instance profiles."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ingress_host" {
  description = "Fully-qualified hostname to expose OpenObserve on (e.g. openobserve.example.com)."
  type        = string
}

variable "ingress_tls_secret" {
  description = "Name of the Kubernetes TLS secret for HTTPS. Created by cert-manager when using the cert-manager annotation."
  type        = string
  default     = ""
}

variable "storage_class" {
  description = "StorageClass name for persistent volumes. Defaults to the cluster default when empty."
  type        = string
  default     = ""
}
