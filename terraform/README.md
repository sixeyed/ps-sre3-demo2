# Terraform Infrastructure Deployment

This directory contains the Terraform configuration for deploying the reliability demo infrastructure to Azure.

## Prerequisites

- **PowerShell 7+** (for the deployment script)
- **Terraform** >= 1.5.0
- **Azure CLI** configured and logged in
- **kubectl** (for post-deployment verification)

## Quick Start

### 1. Install Tools (macOS)

```powershell
# Run from the project root
./m2/demo2/tools/install-tools-macos.ps1
```

### 2. Azure Authentication

```powershell
# Login to Azure
az login

# Set subscription if needed
az account set --subscription "Your Subscription Name"
```

### 3. Deploy Infrastructure

```powershell
# Navigate to terraform directory
cd terraform

# Validate configuration
./deploy.ps1 -Action validate

# Create deployment plan
./deploy.ps1 -Action plan -Environment demo

# Apply the plan
./deploy.ps1 -Action apply -Environment demo
```

## Deployment Script Usage

The `deploy.ps1` script automates the entire deployment process:

### Basic Usage

```powershell
# Plan deployment (default)
./deploy.ps1

# Apply deployment
./deploy.ps1 -Action apply

# Destroy infrastructure
./deploy.ps1 -Action destroy
```

### Advanced Usage

```powershell
# Deploy to production environment
./deploy.ps1 -Action apply -Environment production -Location westeurope

# Auto-approve (non-interactive)
./deploy.ps1 -Action apply -AutoApprove

# Skip Terraform init (if already initialized)
./deploy.ps1 -Action apply -SkipInit

# Use custom state storage
./deploy.ps1 -Action apply -TerraformStateSA "mycustomstateaccount"
```

### Parameters

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `Action` | Terraform action to perform | `plan` | `plan`, `apply`, `destroy`, `validate` |
| `Environment` | Deployment environment | `demo` | `demo`, `staging`, `production` |
| `Location` | Azure region | `westeurope` | Any Azure region |
| `AutoApprove` | Skip confirmation prompts | `false` | Switch parameter |
| `SkipInit` | Skip Terraform initialization | `false` | Switch parameter |
| `TerraformStateRG` | State storage resource group | `terraform-state-rg` | String |
| `TerraformStateSA` | State storage account name | Auto-generated | String |
| `TerraformStateContainer` | State blob container | `tfstate` | String |

## What Gets Deployed

The Terraform configuration creates:

- **Resource Group**: Container for all resources
- **AKS Cluster**: Kubernetes cluster with autoscaling
- **Node Pools**: Worker nodes across availability zones
- **ArgoCD**: GitOps deployment tool
- **Namespaces**: reliability-demo, argocd, monitoring
- **RBAC**: Role-based access control
- **Monitoring**: Basic observability setup

## Post-Deployment

After successful deployment, the script will:

1. **Configure kubectl** with AKS credentials
2. **Verify cluster access** by listing nodes
3. **Provide next steps** for accessing ArgoCD

### Access ArgoCD

```powershell
# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
```

Access https://localhost:8080 with username `admin`

### Verify Deployment

```powershell
# Check cluster status
kubectl get nodes

# Check ArgoCD applications
kubectl get applications -n argocd

# Check reliability-demo namespace
kubectl get all -n reliability-demo
```

## State Management

The script automatically manages Terraform state:

1. **Creates state backend** if it doesn't exist
2. **Uses existing backend** if found
3. **Stores state** in Azure Blob Storage
4. **Environment-specific** state files

### Manual State Operations

```powershell
# List state
terraform state list

# Show specific resource
terraform state show azurerm_resource_group.main

# Import existing resource
terraform import azurerm_resource_group.main /subscriptions/.../resourceGroups/my-rg
```

## Troubleshooting

### Common Issues

**Terraform not found**:
```powershell
# Install Terraform
brew install hashicorp/tap/terraform
```

**Azure login required**:
```powershell
# Login to Azure
az login
```

**State lock error**:
```powershell
# Force unlock (use carefully)
terraform force-unlock <LOCK_ID>
```

**Resource already exists**:
```powershell
# Import existing resource
terraform import <resource_type>.<name> <resource_id>
```

### Logs and Debugging

```powershell
# Enable Terraform debug logging
$env:TF_LOG = "DEBUG"
./deploy.ps1 -Action plan

# Check Azure resource group
az group show --name reliability-demo-demo

# Check AKS cluster
az aks show --resource-group reliability-demo-demo --name aks-reliability-demo-demo
```

## Environment Variables

Optional environment variables:

```powershell
# Terraform logging
$env:TF_LOG = "INFO"          # DEBUG, INFO, WARN, ERROR

# Azure authentication (alternative to az login)
$env:ARM_CLIENT_ID = "..."
$env:ARM_CLIENT_SECRET = "..."
$env:ARM_SUBSCRIPTION_ID = "..."
$env:ARM_TENANT_ID = "..."
```

## Files Structure

```
terraform/
├── deploy.ps1              # Deployment script
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars.example # Example variables
├── modules/                # Reusable modules
│   ├── aks/               # AKS cluster module
│   └── argocd/            # ArgoCD installation
└── test/                  # Test files
    ├── integration/       # Integration tests
    └── unit/             # Unit tests
```

## Next Steps

After deployment:

1. **Configure GitOps**: Applications will auto-deploy via ArgoCD
2. **Set up monitoring**: Prometheus and Grafana (if enabled)
3. **Deploy applications**: Use the CI/CD workflows
4. **Scale testing**: Run load tests against the cluster

For complete GitOps workflow, see the main [GitOps Guide](../README-GITOPS.md).