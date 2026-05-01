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
