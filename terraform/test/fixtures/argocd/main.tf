terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11.0"
    }
  }
}

# Mock providers for testing
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Create test namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd-test"
  }
}

# Use the ArgoCD module
module "argocd" {
  source = "../../../modules/argocd"
  
  namespace            = kubernetes_namespace.argocd.metadata[0].name
  argocd_chart_version = "5.51.6"
  git_repo_url         = "https://github.com/sixeyed/ps-sre3-demo2"
  git_target_revision  = "main"
}