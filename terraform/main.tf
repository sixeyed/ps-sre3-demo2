terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatereliability"
    container_name       = "tfstate"
    key                  = "reliability-demo.tfstate"
  }
}

provider "azurerm" {
  skip_provider_registration = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "kubernetes" {
  host                   = module.aks.kube_config.host
  client_certificate     = base64decode(module.aks.kube_config.client_certificate)
  client_key             = base64decode(module.aks.kube_config.client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kube_config.host
    client_certificate     = base64decode(module.aks.kube_config.client_certificate)
    client_key             = base64decode(module.aks.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.aks.kube_config.cluster_ca_certificate)
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# Log Analytics Workspace for AKS monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# AKS Cluster
module "aks" {
  source = "./modules/aks"

  cluster_name        = var.cluster_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  kubernetes_version  = var.kubernetes_version

  node_count     = var.node_count
  node_vm_size   = var.node_vm_size
  node_disk_size = var.node_disk_size

  enable_auto_scaling = var.enable_auto_scaling
  min_node_count      = var.min_node_count
  max_node_count      = var.max_node_count

  # ARM64 node pool configuration
  enable_arm64_nodes   = var.enable_arm64_nodes
  arm64_node_vm_size   = var.arm64_node_vm_size
  arm64_node_count     = var.arm64_node_count
  arm64_min_node_count = var.arm64_min_node_count
  arm64_max_node_count = var.arm64_max_node_count

  # Cluster autoscaler configuration
  autoscaler_scale_down_delay_after_add       = var.autoscaler_scale_down_delay_after_add
  autoscaler_scale_down_unneeded_time         = var.autoscaler_scale_down_unneeded_time
  autoscaler_scale_down_utilization_threshold = var.autoscaler_scale_down_utilization_threshold

  # Enable monitoring with Log Analytics
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  tags = var.tags
}

# Namespaces
resource "kubernetes_namespace" "reliability_demo" {
  metadata {
    name = "reliability-demo"
  }

  depends_on = [module.aks]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.aks]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }

  depends_on = [module.aks]
}

# KEDA for event-driven autoscaling (optional, installed before ArgoCD)
module "keda" {
  count = var.enable_keda ? 1 : 0
  
  source = "./modules/keda"

  depends_on = [module.aks]
}

# ArgoCD
module "argocd" {
  source = "./modules/argocd"

  namespace = kubernetes_namespace.argocd.metadata[0].name

  depends_on = [module.aks]
}

# ArgoCD Applications (depends on KEDA if enabled)
resource "helm_release" "argocd_apps" {
  name      = "argocd-apps"
  namespace = kubernetes_namespace.argocd.metadata[0].name
  chart     = "./charts/argocd-apps"

  set {
    name  = "spec.source.repoURL"
    value = var.git_repo_url
  }

  set {
    name  = "spec.source.targetRevision"
    value = var.git_target_revision
  }

  set {
    name  = "profile"
    value = var.tags.Profile != null ? var.tags.Profile : "default"
  }

  depends_on = [module.argocd]
}

# Outputs
output "kube_config" {
  value     = module.aks.kube_config_raw
  sensitive = true
}

output "cluster_name" {
  value = module.aks.cluster_name
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "argocd_server_url" {
  value = module.argocd.server_url
}

output "argocd_initial_password" {
  value     = module.argocd.initial_admin_password
  sensitive = true
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

