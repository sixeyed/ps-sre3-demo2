terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Minimal resource group for testing
resource "azurerm_resource_group" "test" {
  name     = "test-rg-fixture"
  location = "westeurope"
}

# Use the AKS module with minimal configuration
module "aks" {
  source = "../../../modules/aks"
  
  cluster_name        = "test-aks-fixture"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  kubernetes_version  = "1.28.3"
  
  # Minimal configuration for testing
  node_count           = 1
  node_vm_size         = "Standard_B2s"
  node_disk_size       = 30
  enable_auto_scaling  = false
  
  tags = {
    Environment = "Test"
    Purpose     = "Fixture"
  }
}