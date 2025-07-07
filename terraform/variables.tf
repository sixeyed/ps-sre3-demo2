variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "reliability-demo-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "reliability-demo-aks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28.3"
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
    Environment = "Demo"
    ManagedBy   = "Terraform"
    Project     = "ReliabilityDemo"
  }
}