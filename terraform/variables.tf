variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "pergamo-432919"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "datatechsolutions-tools"
}

variable "base_domain" {
  description = "Base domain for services"
  type        = string
  default     = "tools.datatechsolutions.com.br"
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-micro"
}

variable "disk_size_gb" {
  description = "Disk size in GB for each node"
  type        = number
  default     = 10
}