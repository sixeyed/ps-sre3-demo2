variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "reliability-demo-demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-reliability-demo-demo"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.32.4"
}

variable "node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 3
}

variable "node_vm_size" {
  description = "VM size for node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "node_disk_size" {
  description = "OS disk size in GB"
  type        = number
  default     = 100
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling for node pool"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum nodes when auto scaling"
  type        = number
  default     = 3
}

variable "max_node_count" {
  description = "Maximum nodes when auto scaling"
  type        = number
  default     = 10
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD apps"
  type        = string
  default     = "https://github.com/sixeyed/ps-sre3-demo2"
}

variable "git_target_revision" {
  description = "Git branch/tag/commit for ArgoCD apps"
  type        = string
  default     = "main"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "demo"
    ManagedBy   = "Terraform"
    Project     = "ReliabilityDemo"
  }
}

# ARM64 node pool variables
variable "enable_arm64_nodes" {
  description = "Enable ARM64 node pool for Apple Silicon builds"
  type        = bool
  default     = true
}

variable "arm64_node_vm_size" {
  description = "VM size for ARM64 node pool"
  type        = string
  default     = "Standard_D2ps_v5"  # ARM64-based VM
}

variable "arm64_node_count" {
  description = "Initial number of ARM64 nodes"
  type        = number
  default     = 1
}

variable "arm64_min_node_count" {
  description = "Minimum number of ARM64 nodes for autoscaling"
  type        = number
  default     = 0
}

variable "arm64_max_node_count" {
  description = "Maximum number of ARM64 nodes for autoscaling"
  type        = number
  default     = 3
}

# Azure Container Registry variables
variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "reliabilitydemoacr"
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

variable "acr_admin_enabled" {
  description = "Enable admin user for Azure Container Registry"
  type        = bool
  default     = true
}