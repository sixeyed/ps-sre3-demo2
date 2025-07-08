resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = var.enable_auto_scaling ? null : var.node_count
    vm_size             = var.node_vm_size
    os_disk_size_gb     = var.node_disk_size
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.enable_auto_scaling ? var.min_node_count : null
    max_count           = var.enable_auto_scaling ? var.max_node_count : null
    
    # Enable availability zones for HA
    zones = ["1", "2", "3"]
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  # Enable monitoring (only if workspace ID is provided)
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != "" ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  # Auto-upgrade for patch versions
  automatic_channel_upgrade = "patch"

  tags = var.tags
}

# Additional node pool for workloads
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.node_vm_size
  node_count            = var.enable_auto_scaling ? null : var.node_count
  enable_auto_scaling   = var.enable_auto_scaling
  min_count             = var.enable_auto_scaling ? var.min_node_count : null
  max_count             = var.enable_auto_scaling ? var.max_node_count : null
  
  # Enable availability zones for HA
  zones = ["1", "2", "3"]
  
  # Node labels for workload segregation
  node_labels = {
    "workload-type" = "application"
  }
  
  # Taints for dedicated workload nodes
  node_taints = []

  tags = var.tags
}