# Demo 2: Production-Ready GitOps Recording Guide

## Pre-Demo Setup

- Azure subscription with contributor access
- PowerShell 7+
- GitHub repository with secrets configured
- kubectl installed
- Broken test image available in registry

## Demo Recording Steps

### Step 1: Show Repository Structure

```powershell
# Show repository structure
Get-ChildItem -Directory | Select-Object Name
```

**Files to show:**
> [`terraform/main.tf`](../../terraform/main.tf)
> [`terraform/variables.tf`](../../terraform/variables.tf)

### Step 2: Show Helm Chart Improvements

**Files to show:**
> [`helm/app/templates/deployment.yaml`](../../helm/app/templates/deployment.yaml) - Navigate to health check sections
> [`helm/app/values.yaml`](../../helm/app/values.yaml) - Show probe configuration
> [`helm/app/templates/hpa.yaml`](../../helm/app/templates/hpa.yaml) - Show autoscaling

### Step 3: Show ArgoCD Configuration

**Files to show:**
> [`terraform/modules/argocd/main.tf`](../../terraform/modules/argocd/main.tf)
> [`argocd-apps/reliability-demo.yaml`](../../argocd-apps/reliability-demo.yaml)

### Step 4: Deploy Infrastructure via GitHub Actions

**Show workflow:**
> [`.github/workflows/deploy-infrastructure.yml`](../../.github/workflows/deploy-infrastructure.yml)

**Trigger deployment:**
1. Go to GitHub repository
2. Navigate to Actions tab
3. Select "Deploy Infrastructure" workflow
4. Click "Run workflow"
5. Select:
   - Environment: `production`
   - Action: `apply`
6. Click "Run workflow"

**Monitor deployment progress in GitHub Actions UI**

### Step 5: Verify Infrastructure

```powershell
# Once deployment completes, get AKS credentials
az aks get-credentials --resource-group reliability-demo-prod --name aks-reliability-demo-prod

# Verify cluster
kubectl get nodes
kubectl get ns
```

### Step 6: Demonstrate CI/CD Workflow

**Show workflow:**
> [`.github/workflows/build-pr.yml`](../../.github/workflows/build-pr.yml)

**Create feature branch:**
```powershell
git checkout -b feature/update-reliability
# Make small change to src/ReliabilityDemo/Program.cs
git add .
git commit -m "Update reliability feature"
git push origin feature/update-reliability
```

**In GitHub UI:**
- Create Pull Request
- Show PR checks running
- Merge PR

### Step 7: Deploy with Version Tag

**Show workflow:**
> [`.github/workflows/release.yml`](../../.github/workflows/release.yml)

```powershell
# Switch back to main and pull
git checkout main
git pull origin main

# Tag and push
git tag v1.2.3
git push origin v1.2.3
```

**Monitor in GitHub Actions**

### Step 8: Watch ArgoCD Sync

```powershell
# Watch pods rolling update
kubectl get pods -n reliability-demo -w
```

### Step 9: Demonstrate Self-Healing

```powershell
# Delete a pod
$podName = kubectl get pods -n reliability-demo -o jsonpath='{.items[0].metadata.name}'
kubectl delete pod $podName -n reliability-demo

# Watch recovery
kubectl get pods -n reliability-demo -w
```

### Step 10: Configuration Drift Protection

```powershell
# Manually patch deployment
kubectl patch deployment reliability-demo-web -n reliability-demo `
  --type='json' `
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "DRIFT_TEST", "value": "manual-change"}}]'

# Check ArgoCD status
kubectl get application reliability-demo -n argocd
```

**Wait for ArgoCD to revert the change**

### Step 11: Deploy Broken Version

```powershell
# Update values to use broken image
$valuesPath = "helm/app/values.yaml"
$values = Get-Content $valuesPath
$values = $values -replace 'tag: ".*"', 'tag: "broken-test"'
$values | Set-Content $valuesPath

# Commit and tag
git add .
git commit -m "Deploy broken version for testing"
git tag v1.2.4
git push origin main
git push origin v1.2.4
```

```powershell
# Watch deployment fail
kubectl get pods -n reliability-demo -w
```

### Step 12: Emergency Rollback

```powershell
# Revert the broken change
git revert HEAD --no-edit
git push origin main

# Watch ArgoCD sync back
kubectl get pods -n reliability-demo -w
```

### Step 13: Show ArgoCD Dashboard

```powershell
# Get ArgoCD password
$argoPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
$argoPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($argoPassword))

Write-Host "ArgoCD Password: $argoPassword"

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Open https://localhost:8080 in browser**
- Username: admin
- Show application sync status
- Show health status

### Step 14: Show Metrics Comparison

```powershell
# Display comparison
@"
Deployment Metrics Comparison:

Manual Process (Demo 1):
- Deployment Time: 10+ minutes with issues
- Error Rate: Multiple failures per deployment  
- Rollback Time: Manual process, hours
- Manual Steps: 10+ error-prone steps

Automated GitOps (Demo 2):
- Deployment Time: 2 minutes, zero downtime
- Error Rate: Failures prevented automatically
- Rollback Time: 30 seconds with git revert
- Manual Steps: 1 git tag command
"@ | Write-Host -ForegroundColor Green
```

## Post-Demo Cleanup

**Via GitHub Actions:**
1. Go to Actions tab
2. Run "Deploy Infrastructure" workflow
3. Select:
   - Environment: `production`
   - Action: `destroy`
4. Confirm destruction

## Files to Have Ready

1. [`terraform/main.tf`](../../terraform/main.tf)
2. [`helm/app/templates/deployment.yaml`](../../helm/app/templates/deployment.yaml)
3. [`helm/app/values.yaml`](../../helm/app/values.yaml)
4. [`argocd-apps/reliability-demo.yaml`](../../argocd-apps/reliability-demo.yaml)
5. [`.github/workflows/release.yml`](../../.github/workflows/release.yml)
6. [`.github/workflows/deploy-infrastructure.yml`](../../.github/workflows/deploy-infrastructure.yml)

## Pre-Recording Checklist

- [ ] Azure credentials configured in GitHub secrets
- [ ] Broken test image pushed to registry
- [ ] Terminal and VS Code arranged side by side
- [ ] GitHub Actions tab open in browser
- [ ] Test all PowerShell commands
- [ ] Clear terminal history