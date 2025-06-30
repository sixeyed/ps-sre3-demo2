variable "namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "5.51.6"
}

variable "git_repo_url" {
  description = "Git repository URL for app-of-apps"
  type        = string
  default     = ""
}

variable "git_target_revision" {
  description = "Git branch/tag/commit for app-of-apps"
  type        = string
  default     = "main"
}