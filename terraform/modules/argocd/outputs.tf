output "server_url" {
  description = "ArgoCD server URL"
  value       = "http://argocd-server.${var.namespace}.svc.cluster.local"
}

output "initial_admin_password" {
  description = "Initial admin password for ArgoCD"
  value       = try(data.kubernetes_secret.argocd_initial_admin_secret.data.password, "")
  sensitive   = true
}