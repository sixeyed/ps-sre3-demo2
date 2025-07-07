# GitOps Deployment Guide

This guide covers the GitOps deployment process using GitHub Actions and ArgoCD for the reliability demo application.

## 🚀 Infrastructure Deployment

### Prerequisites

1. **Azure Subscription** with appropriate permissions
2. **GitHub Repository** with Actions enabled
3. **PowerShell 7+** for setup scripts

### Azure Setup

#### 1. Create Service Principal for GitHub Actions

```powershell
# Set your subscription ID
$subscriptionId = az account show --query id -o tsv

# Create service principal
$sp = az ad sp create-for-rbac `
  --name "github-actions-ps-sre3-demo2" `
  --role contributor `
  --scopes "/subscriptions/$subscriptionId" `
  --json-auth

# Display the credentials (save these!)
$sp | ConvertFrom-Json | ConvertTo-Json
```

#### 2. Create Terraform State Backend

```powershell
# Create resource group for Terraform state
az group create --name terraform-state-rg --location westeurope

# Create storage account (must be globally unique)
$storageAccount = "tfstate$(Get-Random -Maximum 99999)"
az storage account create `
  --resource-group terraform-state-rg `
  --name $storageAccount `
  --sku Standard_LRS `
  --encryption-services blob

# Create blob container
az storage container create `
  --name tfstate `
  --account-name $storageAccount

Write-Host "Storage Account Name: $storageAccount"
```

#### 3. Configure GitHub Secrets

Go to your GitHub repository **Settings** → **Secrets and variables** → **Actions** and add:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `AZURE_CLIENT_ID` | From service principal output | Azure AD App ID |
| `AZURE_CLIENT_SECRET` | From service principal output | Azure AD App Secret |
| `AZURE_SUBSCRIPTION_ID` | From service principal output | Azure Subscription ID |
| `AZURE_TENANT_ID` | From service principal output | Azure AD Tenant ID |
| `TERRAFORM_STATE_RG` | `terraform-state-rg` | Resource group for TF state |
| `TERRAFORM_STATE_SA` | Your storage account name | Storage account for TF state |
| `TERRAFORM_STATE_CONTAINER` | `tfstate` | Container name for state files |

### Deploy Infrastructure

1. **Go to Actions tab** in GitHub
2. Select **"Deploy Infrastructure"** workflow
3. Click **"Run workflow"**
4. Select:
   - Environment: `production`
   - Action: `plan` (first run to review)
5. Review the plan output
6. Run again with Action: `apply`

The workflow will:
- Create Azure Resource Group
- Deploy AKS cluster with autoscaling
- Install ArgoCD with GitOps configuration
- Configure namespaces and RBAC

## 📦 Container Registry Setup

### GitHub Container Registry (GHCR)

The GitHub workflows automatically push images to GHCR. No additional setup required - the workflows use the built-in `GITHUB_TOKEN`.

**To make images publicly accessible** (recommended for demos):
1. Go to repository **Packages** tab
2. Click on each package
3. Go to **Package settings**
4. Change visibility to **Public**

## 🚢 Application Deployment

### Deployment Workflow

1. **Create a Pull Request**:
   ```powershell
   git checkout -b feature/update-app
   # Make changes
   git add .
   git commit -m "Update application"
   git push origin feature/update-app
   ```

2. **PR Workflow** automatically:
   - Builds Docker images
   - Pushes to GHCR staging repository
   - Runs tests and security scans

3. **After PR merge, tag for release**:
   ```powershell
   git checkout main
   git pull origin main
   git tag v1.2.3
   git push origin v1.2.3
   ```

4. **Release Workflow** automatically:
   - Builds production images
   - Tags with version number
   - Updates Helm chart versions
   - Commits back to repository
   - ArgoCD detects and deploys changes

### Emergency Rollback

```powershell
# Quick rollback via Git
git revert HEAD --no-edit
git push origin main

# ArgoCD will automatically sync the revert
```

## 🔍 Monitoring Deployment

### Access ArgoCD Dashboard

```powershell
# Get AKS credentials
az aks get-credentials `
  --resource-group reliability-demo-prod `
  --name aks-reliability-demo-prod

# Get ArgoCD password
$password = kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}"
$password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))

Write-Host "ArgoCD Admin Password: $password"

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access https://localhost:8080 with username `admin`

### View Application Status

```powershell
# Check application sync status
kubectl get application -n argocd

# View pods
kubectl get pods -n reliability-demo

# Check deployments
kubectl get deployments -n reliability-demo
```

## 🧹 Cleanup

To destroy all infrastructure:

1. Go to GitHub **Actions** tab
2. Run **"Deploy Infrastructure"** workflow
3. Select:
   - Environment: `production`
   - Action: `destroy`
4. Confirm the destruction

This will remove:
- AKS cluster and all workloads
- Resource group and all resources
- Terraform state remains for audit

## 📋 Troubleshooting

### Common Issues

**Terraform state lock**:
```powershell
# Force unlock if needed
terraform force-unlock <LOCK_ID>
```

**ArgoCD sync issues**:
```powershell
# Force sync
kubectl patch application reliability-demo -n argocd `
  --type merge `
  --patch '{"spec":{"syncPolicy":null}}'
```

**Image pull errors**:
- Ensure packages are set to public visibility
- Check image exists in GHCR
- Verify image tag matches Helm values

## 🔗 Repository Structure

```
.github/workflows/
├── build-pr.yml          # PR validation and staging build
├── release.yml           # Production release workflow
└── deploy-infrastructure.yml  # Infrastructure deployment

helm/app/                 # Application Helm chart
├── templates/            # Kubernetes manifests
└── values.yaml          # Default configuration

argocd-apps/             # ArgoCD application definitions
└── reliability-demo.yaml

terraform/               # Infrastructure as Code
├── main.tf             # Main configuration
├── variables.tf        # Input variables
└── modules/            # Reusable modules
    ├── aks/           # AKS cluster module
    └── argocd/        # ArgoCD installation
```