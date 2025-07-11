# M3 Demo 1 - Static Infrastructure Profile
# This profile demonstrates wasted cloud resources with oversized VMs and no autoscaling

# Basic configuration - names will be set by the deploy script based on environment
# Only override sizing and scaling parameters for this profile

# Large VM sizes for demonstration of waste (adjusted for quota)
node_vm_size = "Standard_D4s_v5"     # 4 vCPUs, 16 GB RAM - large but within quota
node_count = 3                        # Fixed size, no autoscaling
enable_auto_scaling = false
min_node_count = 3                    # Not used when autoscaling disabled
max_node_count = 3                    # Not used when autoscaling disabled

# Disable ARM64 nodes to save quota for workload pool
enable_arm64_nodes = false
# arm64_node_vm_size = "Standard_D2ps_v5"  # 2 vCPUs, 8 GB RAM - ARM64 within quota
# arm64_node_count = 2                      # Reduced count to fit quota
# arm64_min_node_count = 2                  # Not used when autoscaling disabled  
# arm64_max_node_count = 2                  # Not used when autoscaling disabled

# Standard networking and disk settings
node_disk_size = 100
# kubernetes_version = "1.28"  # Commented out - let Azure choose supported version

# Git repository configuration for ArgoCD
git_repo_url = "https://github.com/sixeyed/ps-sre3-demo2.git"
git_target_revision = "main"

# Tags for cost tracking
tags = {
  Environment = "demo"
  Profile     = "m3demo1"
  Purpose     = "static-infrastructure-waste-demo"
  CostCenter  = "sre-training"
}