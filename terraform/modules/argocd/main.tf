resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = var.namespace
  create_namespace = false
  version          = var.argocd_chart_version

  values = [
    yamlencode({
      server = {
        # Enable server-side health checks
        extraArgs = [
          "--insecure"  # Disable TLS but keep authentication
        ]
        
        # Resource limits for self-healing demo
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
        
        # Multiple replicas for HA
        replicas = 2
        
        # Service configuration
        service = {
          type = "LoadBalancer"
        }
        
        # Enable metrics
        metrics = {
          enabled = true
        }
      }
      
      controller = {
        # Resource limits
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        
        # Enable self-healing
        enableStatefulSet = true
        
        # Metrics for monitoring
        metrics = {
          enabled = true
        }
      }
      
      repoServer = {
        # Multiple replicas for HA
        replicas = 2
        
        # Resource limits
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
      }
      
      # Redis HA
      redis = {
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
      
      # Enable dex for OIDC (optional)
      dex = {
        enabled = false
      }
      
      # Global configuration
      global = {
        logging = {
          level = "info"
          format = "json"
        }
      }
    })
  ]
}

# Get initial admin password
data "kubernetes_secret" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }
  
  depends_on = [helm_release.argocd]
}

# Create app-of-apps pattern for GitOps
# Note: App-of-apps pattern commented out due to chicken-and-egg problem
# The kubernetes_manifest resource requires API access during plan phase,
# which fails when the cluster doesn't exist yet.
# 
# This will be configured via the ArgoCD applications in the main module
# using the helm chart approach instead.