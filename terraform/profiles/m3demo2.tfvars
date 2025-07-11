# M3 Demo 2 - Dynamic Scaling Profile
# This profile demonstrates right-sized infrastructure with autoscaling enabled

# Basic configuration - names will be set by the deploy script based on environment
# Only override sizing and scaling parameters for this profile

# Right-sized VM configuration with autoscaling enabled
node_vm_size = "Standard_D4s_v5"       # 4 vCPUs, 16 GB RAM - right-sized for efficiency
node_count = 3                          # Initial baseline nodes
enable_auto_scaling = true              # Enable cluster autoscaler
min_node_count = 2                      # Minimum for availability
max_node_count = 7                      # Maximum for cost control

# ARM64 nodes with D4ps_v5 for app components  
enable_arm64_nodes = true
arm64_node_vm_size = "Standard_D4ps_v5" # 4 vCPUs, 16 GB RAM - ARM64 D4 equivalent
arm64_node_count = 3                    # Initial baseline nodes
arm64_min_node_count = 2                # Minimum for availability
arm64_max_node_count = 7                # Maximum for cost control

# Autoscaling configuration
autoscaler_scale_down_delay_after_add = "10m"       # Wait 10m after scale-up before considering scale-down
autoscaler_scale_down_unneeded_time = "10m"         # Node must be unneeded for 10m before removal
autoscaler_scale_down_utilization_threshold = 0.5   # Remove nodes when utilization < 50%

# Standard networking and disk settings
node_disk_size = 100
# kubernetes_version = "1.28"  # Commented out - let Azure choose supported version

# Enable KEDA for event-driven autoscaling
enable_keda = true

# Git repository configuration for ArgoCD
git_repo_url = "https://github.com/sixeyed/ps-sre3-demo2.git"
git_target_revision = "main"

# Tags for cost tracking
tags = {
  Environment = "demo"
  Profile     = "m3demo2"
  Purpose     = "dynamic-scaling-autoscaling-demo"
  CostCenter  = "sre-training"
}