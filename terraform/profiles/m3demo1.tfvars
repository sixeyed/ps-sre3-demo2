# M3 Demo 1 - Static Infrastructure Profile
# This profile demonstrates wasted cloud resources with oversized VMs and no autoscaling

# Basic configuration - names will be set by the deploy script based on environment
# Only override sizing and scaling parameters for this profile

# Large VM sizes for demonstration of waste
node_vm_size = "Standard_D8s_v5"     # 8 vCPUs, 32 GB RAM - latest D8 size
node_count = 3                        # Fixed size, no autoscaling
enable_auto_scaling = false
min_node_count = 3                    # Not used when autoscaling disabled
max_node_count = 3                    # Not used when autoscaling disabled

# Large ARM64 nodes for demonstration
enable_arm64_nodes = true
arm64_node_vm_size = "Standard_D8ps_v5"  # 8 vCPUs, 32 GB RAM - ARM64 equivalent
arm64_node_count = 3                      # Fixed size, no autoscaling
arm64_min_node_count = 3                  # Not used when autoscaling disabled  
arm64_max_node_count = 3                  # Not used when autoscaling disabled

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