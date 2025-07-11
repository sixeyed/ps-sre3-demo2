#!/usr/bin/env pwsh

# deploy.ps1 - Deploy Terraform Infrastructure
# This script deploys the reliability demo infrastructure using Terraform

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("plan", "apply", "destroy", "validate", "force-unlock")]
    [string]$Action = "plan",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("demo", "staging", "production")]
    [string]$Environment = "demo",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westeurope",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("default", "m3demo1")]
    [string]$Profile = "default",
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInit,
    
    [Parameter(Mandatory=$false)]
    [string]$TerraformStateRG = "terraform-state-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$TerraformStateSA = "",
    
    [Parameter(Mandatory=$false)]
    [string]$TerraformStateContainer = "tfstate"
)

# Color output functions
function Write-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Warning { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host $Message -ForegroundColor Red }

# Header
Write-Success "=============================================="
Write-Success "Terraform Infrastructure Deployment"
Write-Success "=============================================="
Write-Info "Action: $Action"
Write-Info "Environment: $Environment"
Write-Info "Location: $Location"
Write-Info "Profile: $Profile"
Write-Host ""

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check if Terraform is installed
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error "Terraform is not installed or not in PATH"
    Write-Host "Install with: brew install hashicorp/tap/terraform"
    exit 1
}

# Check if Azure CLI is installed and logged in
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed or not in PATH"
    Write-Host "Install with: brew install azure-cli"
    exit 1
}

# Check Azure login
try {
    $account = az account show --query name -o tsv 2>$null
    if (-not $account) {
        throw "Not logged in"
    }
    Write-Success "✓ Azure CLI logged in as: $account"
} catch {
    Write-Error "Not logged in to Azure. Please run: az login"
    exit 1
}

# Get subscription info
$subscriptionId = az account show --query id -o tsv
$subscriptionName = az account show --query name -o tsv
Write-Info "Using subscription: $subscriptionName ($subscriptionId)"

# Check if state storage account name is provided
if ([string]::IsNullOrEmpty($TerraformStateSA)) {
    Write-Info "No state storage account specified. Checking for existing one..."
    
    # Try to find existing storage account
    $existingSA = az storage account list --resource-group $TerraformStateRG --query "[0].name" -o tsv 2>$null
    
    if ($existingSA) {
        $TerraformStateSA = $existingSA
        Write-Success "✓ Found existing storage account: $TerraformStateSA"
    } else {
        Write-Warning "No storage account found. Creating state backend..."
        
        # Create resource group if it doesn't exist
        $rgExists = az group exists --name $TerraformStateRG
        if ($rgExists -eq "false") {
            Write-Info "Creating resource group: $TerraformStateRG"
            az group create --name $TerraformStateRG --location $Location
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to create resource group"
                exit 1
            }
        }
        
        # Generate unique storage account name
        $TerraformStateSA = "tfstate$(Get-Random -Maximum 99999)"
        
        Write-Info "Creating storage account: $TerraformStateSA"
        az storage account create `
            --resource-group $TerraformStateRG `
            --name $TerraformStateSA `
            --sku Standard_LRS `
            --encryption-services blob `
            --location $Location
            
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create storage account"
            exit 1
        }
        
        # Create container
        Write-Info "Creating blob container: $TerraformStateContainer"
        az storage container create `
            --name $TerraformStateContainer `
            --account-name $TerraformStateSA
            
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create blob container"
            exit 1
        }
        
        Write-Success "✓ Terraform state backend created"
    }
}

# Terraform initialization
if (-not $SkipInit) {
    Write-Info "Initializing Terraform..."
    
    terraform init `
        -backend-config="resource_group_name=$TerraformStateRG" `
        -backend-config="storage_account_name=$TerraformStateSA" `
        -backend-config="container_name=$TerraformStateContainer" `
        -backend-config="key=$Environment.terraform.tfstate"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform initialization failed"
        exit 1
    }
    
    Write-Success "✓ Terraform initialized"
}

# Validate Terraform configuration
if ($Action -eq "validate" -or $Action -eq "plan") {
    Write-Info "Validating Terraform configuration..."
    terraform validate
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform validation failed"
        exit 1
    }
    
    Write-Success "✓ Terraform configuration is valid"
}

# Execute the requested action
switch ($Action) {
    "validate" {
        Write-Success "✓ Validation completed successfully"
    }
    
    "plan" {
        Write-Info "Creating Terraform plan..."
        
        # Set resource names based on environment
        $resourceGroupName = "reliability-demo-$Environment"
        $clusterName = "aks-reliability-demo-$Environment"
        
        # Build Terraform command with profile support
        $planArgs = @(
            "plan"
            "-var=resource_group_name=$resourceGroupName"
            "-var=cluster_name=$clusterName"
            "-var=location=$Location"
            "-out=tfplan"
        )
        
        # Add profile-specific tfvars file if not default
        if ($Profile -ne "default") {
            $profileFile = "profiles/$Profile.tfvars"
            if (Test-Path $profileFile) {
                Write-Info "Using profile configuration: $profileFile"
                $planArgs += "-var-file=$profileFile"
            } else {
                Write-Warning "Profile file $profileFile not found, using default configuration"
            }
        }
        
        terraform @planArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Plan created successfully"
            Write-Info "Plan saved as 'tfplan'. To apply: ./deploy.ps1 -Action apply"
        } else {
            Write-Error "Plan creation failed"
            exit 1
        }
    }
    
    "apply" {
        if (Test-Path "tfplan") {
            Write-Info "Applying existing plan..."
            if ($AutoApprove) {
                terraform apply -auto-approve tfplan
            } else {
                terraform apply tfplan
            }
        } else {
            Write-Info "No existing plan found. Creating and applying..."
            
            # Set resource names based on environment
            $resourceGroupName = "reliability-demo-$Environment"
            $clusterName = "aks-reliability-demo-$Environment"
            
            $planArgs = @(
                "plan"
                "-var=resource_group_name=$resourceGroupName"
                "-var=cluster_name=$clusterName"
                "-var=location=$Location"
                "-out=tfplan"
            )
            
            # Add profile-specific tfvars file if not default
            if ($Profile -ne "default") {
                $profileFile = "profiles/$Profile.tfvars"
                if (Test-Path $profileFile) {
                    Write-Info "Using profile configuration: $profileFile"
                    $planArgs += "-var-file=$profileFile"
                } else {
                    Write-Warning "Profile file $profileFile not found, using default configuration"
                }
            }
            
            terraform @planArgs
            
            if ($LASTEXITCODE -eq 0) {
                if ($AutoApprove) {
                    terraform apply -auto-approve tfplan
                } else {
                    terraform apply tfplan
                }
            } else {
                Write-Error "Planning failed"
                exit 1
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Infrastructure deployed successfully"
            
            # Get AKS credentials
            Write-Info "Getting AKS credentials..."
            $clusterName = "aks-reliability-demo-$Environment"
            $resourceGroupName = "reliability-demo-$Environment"
            
            az aks get-credentials --resource-group $resourceGroupName --name $clusterName --overwrite-existing
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ Kubernetes credentials configured"
                
                # Verify cluster access
                Write-Info "Verifying cluster access..."
                kubectl get nodes
                
                Write-Host ""
                Write-Success "=== Deployment Complete ==="
                Write-Info "Resource Group: $resourceGroupName"
                Write-Info "AKS Cluster: $clusterName"
                Write-Info "Location: $Location"
                Write-Host ""
                Write-Info "Next steps:"
                Write-Host "1. Access ArgoCD:" -ForegroundColor Gray
                Write-Host "   kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor Gray
                Write-Host "2. Get ArgoCD password:" -ForegroundColor Gray
                Write-Host "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" -ForegroundColor Gray
                Write-Host "3. Check applications:" -ForegroundColor Gray
                Write-Host "   kubectl get applications -n argocd" -ForegroundColor Gray
            } else {
                Write-Warning "Could not get AKS credentials. You may need to run manually:"
                Write-Host "az aks get-credentials --resource-group $resourceGroup --name $clusterName"
            }
        } else {
            Write-Error "Deployment failed"
            exit 1
        }
    }
    
    "destroy" {
        Write-Warning "This will destroy all infrastructure in the $Environment environment!"
        
        if (-not $AutoApprove) {
            $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"
            if ($confirmation -ne "yes") {
                Write-Info "Destruction cancelled"
                exit 0
            }
        }
        
        Write-Info "Destroying infrastructure..."
        
        # Set resource names based on environment
        $resourceGroupName = "reliability-demo-$Environment"
        $clusterName = "aks-reliability-demo-$Environment"
        
        # Build Terraform destroy command with profile support
        $destroyArgs = @(
            "destroy"
            "-var=resource_group_name=$resourceGroupName"
            "-var=cluster_name=$clusterName"
            "-var=location=$Location"
        )
        
        # Add profile-specific tfvars file if not default
        if ($Profile -ne "default") {
            $profileFile = "profiles/$Profile.tfvars"
            if (Test-Path $profileFile) {
                Write-Info "Using profile configuration: $profileFile"
                $destroyArgs += "-var-file=$profileFile"
            } else {
                Write-Warning "Profile file $profileFile not found, using default configuration"
            }
        }
        
        if ($AutoApprove) {
            $destroyArgs += "-auto-approve"
        }
        
        terraform @destroyArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Infrastructure destroyed successfully"
        } else {
            Write-Error "Destruction failed"
            exit 1
        }
    }
    
    "force-unlock" {
        Write-Warning "Force unlocking Terraform state..."
        Write-Info "This will forcefully unlock the Terraform state file."
        
        # Try to force unlock - we need to get the lock ID from the error
        terraform force-unlock -force 62b98f02-90d8-bb8e-0da2-63e3e640036f
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ State unlocked successfully"
        } else {
            Write-Error "Force unlock failed"
            exit 1
        }
    }
}

Write-Host ""
Write-Success "Script completed successfully!"