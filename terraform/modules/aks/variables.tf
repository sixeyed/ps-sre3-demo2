variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 3
}

variable "node_vm_size" {
  description = "VM size for nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "node_disk_size" {
  description = "OS disk size in GB"
  type        = number
  default     = 100
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum nodes for auto scaling"
  type        = number
  default     = 3
}

variable "max_node_count" {
  description = "Maximum nodes for auto scaling"
  type        = number
  default     = 10
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for monitoring"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}