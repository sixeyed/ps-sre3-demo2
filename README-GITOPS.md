# PS SRE3 Demo 2 - GitOps Configuration Repository

This repository contains the GitOps configuration for the Reliability Demo application, showcasing automated deployment with ArgoCD and Kubernetes.

## 🚀 Quick Start

### Prerequisites

Before using this repository, ensure you have:

1. **GitHub Repository Setup** (see [Repository Setup](#repository-setup) below)
2. **Azure AKS Cluster** with ArgoCD installed (via Terraform from main repo)
3. **kubectl** configured to access your cluster

### Repository Setup

#### 1. Azure Authentication Setup

To deploy the infrastructure using GitHub Actions, you need to configure Azure authentication:

**Create Azure Service Principal**:
```bash
# Create service principal and save the output
az ad sp create-for-rbac --name "github-actions-ps-sre3-demo2" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth

# Output will look like:
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  ...
}
```

**Add Repository Secrets**:

Go to **Settings** → **Secrets and variables** → **Actions** and add:

| Secret Name | Value |
|------------|-------|
| `AZURE_CLIENT_ID` | The `clientId` from service principal |
| `AZURE_CLIENT_SECRET` | The `clientSecret` from service principal |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `AZURE_TENANT_ID` | The `tenantId` from service principal |
| `TERRAFORM_STATE_RG` | Resource group for Terraform state (e.g., `terraform-state-rg`) |
| `TERRAFORM_STATE_SA` | Storage account for Terraform state (e.g., `tfstatesre3demo`) |
| `TERRAFORM_STATE_CONTAINER` | Container name for state files (e.g., `tfstate`) |

**Create Terraform State Backend** (one-time setup):
```bash
# Create resource group for Terraform state
az group create --name terraform-state-rg --location eastus

# Create storage account (must be globally unique)
az storage account create \
  --resource-group terraform-state-rg \
  --name tfstatesre3demo \
  --sku Standard_LRS \
  --encryption-services blob

# Create blob container
az storage container create \
  --name tfstate \
  --account-name tfstatesre3demo
```

**Configure Environment Variables** (optional):

Go to **Settings** → **Environments** → Create environments (`demo`, `staging`, `production`) and add:
- `AZURE_LOCATION`: Azure region (default: `eastus`)

#### 2. GitHub Container Registry (GHCR) Permissions

Enable GHCR and set proper permissions:

1. **Enable GHCR for your repository**:
   - Go to repository **Settings** → **General**
   - Scroll to **Features** section
   - Check **Packages** to enable GHCR

2. **Set package visibility** (optional but recommended):
   - Go to your repository **Packages** tab
   - Click on package settings
   - Set visibility to **Public** for easier access from Kubernetes

#### 2. GitHub Actions Permissions

Configure GitHub Actions to access GHCR:

1. **Repository permissions**:
   - Go to **Settings** → **Actions** → **General**
   - Under **Workflow permissions**, select:
     - ✅ **Read and write permissions**
     - ✅ **Allow GitHub Actions to create and approve pull requests**

2. **No additional secrets needed**: The workflow uses the built-in `GITHUB_TOKEN` with enhanced permissions

#### 3. Repository Secrets (Optional)

For enhanced security in production, you can optionally create:

- **Personal Access Token** (if you want more control):
  ```bash
  # Create a PAT with packages:write and contents:write scopes
  # Add as repository secret named 'DEPLOY_TOKEN'
  # Update workflow to use secrets.DEPLOY_TOKEN instead of secrets.GITHUB_TOKEN
  ```

#### 4. Branch Protection (Recommended)

Set up branch protection for the main branch:

1. Go to **Settings** → **Branches**
2. Add rule for `main` branch:
   - ✅ **Require pull request reviews before merging**
   - ✅ **Require status checks to pass before merging**
   - ✅ **Require branches to be up to date before merging**
   - ✅ **Include administrators**

### First Deployment

1. **Fork or clone this repository**
2. **Update image references** (if using different GitHub username):
   ```bash
   # Update GHCR image paths in helm/app/values.yaml
   sed -i 's|ghcr.io/sixeyed/ps-sre3-demo2|ghcr.io/YOUR-USERNAME/YOUR-REPO|g' helm/app/values.yaml
   
   # Update workflow environment variables in .github/workflows/release.yml
   sed -i 's|sixeyed/ps-sre3-demo2|YOUR-USERNAME/YOUR-REPO|g' .github/workflows/release.yml
   
   # Update staging workflow environment variables in .github/workflows/build-pr.yml
   sed -i 's|sixeyed/ps-sre3-demo2|YOUR-USERNAME/YOUR-REPO|g' .github/workflows/build-pr.yml
   ```

3. **Deploy AKS infrastructure**:
   
   **Option A: Using GitHub Actions (Recommended)**
   ```bash
   # Go to Actions tab in GitHub
   # Run "Deploy Infrastructure" workflow
   # Select:
   #   - Action: apply
   #   - Environment: demo
   ```
   
   **Option B: Local Terraform deployment**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

4. **Create your first release**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

5. **Monitor deployment**:
   ```bash
   # Watch ArgoCD deploy the application
   kubectl get applications -n argocd -w
   
   # Watch pods come online
   kubectl get pods -n reliability-demo -w
   ```

## 🔄 Development Workflow

### Making Changes and Deploying

Follow this simple workflow to make changes and trigger deployments:

#### 1. **Create Feature Branch**
```bash
# Clone the repository (if not already done)
git clone https://github.com/sixeyed/ps-sre3-demo2.git
cd ps-sre3-demo2

# Create and switch to a new feature branch
git checkout -b feature/update-app-config
```

#### 2. **Make Your Changes**

**Example: Update application configuration**
```bash
# Edit Helm values to change failure simulation rates
vim helm/app/values.yaml

# Example change:
# config:
#   failureConfig:
#     connectionFailureRate: 0.05  # Reduced from 0.1
#     readTimeoutRate: 0.02        # Reduced from 0.05
```

**Example: Update resource limits**
```bash
# Increase memory limits for higher load
sed -i 's/memory: "512Mi"/memory: "1Gi"/' helm/app/values.yaml
sed -i 's/maxReplicas: 20/maxReplicas: 30/' helm/app/values.yaml
```

#### 3. **Commit and Push Changes**
```bash
# Stage your changes
git add helm/app/values.yaml

# Commit with descriptive message
git commit -m "Update failure rates and increase resource limits

- Reduced connection failure rate from 10% to 5%
- Reduced read timeout rate from 5% to 2%  
- Increased memory limit to 1Gi for better performance
- Increased max replicas to 30 for higher capacity"

# Push feature branch
git push origin feature/update-app-config
```

#### 4. **Create Pull Request**
```bash
# Using GitHub CLI (recommended)
gh pr create --title "Update application configuration" \
  --body "## Changes
- Reduced failure simulation rates for more stable demo
- Increased resource limits for better performance
- Updated scaling parameters for higher capacity

## Testing
- [ ] Helm chart validates successfully
- [ ] Docker images build without errors
- [ ] Security scan passes

## Deployment
After merge, tag with appropriate version (e.g., v1.2.0) to deploy."

# Or create PR through GitHub web interface
echo "Go to: https://github.com/sixeyed/ps-sre3-demo2/compare/main...feature/update-app-config"
```

#### 5. **Review and Merge PR**

The PR will automatically trigger:
- ✅ **Build validation**: Docker images build successfully
- ✅ **Staging deployment**: Images pushed to staging repository
- ✅ **Helm linting**: Chart syntax is valid
- ✅ **Security scanning**: No vulnerabilities found
- ✅ **Template validation**: Kubernetes resources are valid

**Staging Images Created**:
- `ghcr.io/sixeyed/ps-sre3-demo2-staging/reliability-demo:pr-{number}`
- `ghcr.io/sixeyed/ps-sre3-demo2-staging/reliability-demo-worker:pr-{number}`

```bash
# After PR review and approval, merge via GitHub interface
# Or using GitHub CLI:
gh pr merge --squash --delete-branch
```

#### 6. **Tag and Deploy**
```bash
# Switch back to main and pull latest
git checkout main
git pull origin main

# Create version tag (use semantic versioning)
git tag v1.2.0

# Push tag to trigger deployment
git push origin v1.2.0
```

#### 7. **Monitor Deployment**
```bash
# Watch the GitHub Actions workflow
gh workflow view "Build and Deploy Release"

# Monitor ArgoCD application sync
kubectl get applications reliability-demo -n argocd -w

# Watch rolling update
kubectl get pods -n reliability-demo -w

# Check application health
kubectl get deployment reliability-demo-web -n reliability-demo
```

### Quick Commands Reference

```bash
# 🔄 Standard workflow
git checkout -b feature/my-change
# ... make changes ...
git add . && git commit -m "Description of changes"
git push origin feature/my-change
gh pr create --title "My Change" --body "Description"
# ... merge PR via GitHub ...
git checkout main && git pull
git tag v1.2.0 && git push origin v1.2.0

# 🚀 Hotfix workflow (for urgent changes)
git checkout -b hotfix/critical-fix
# ... make critical fix ...
git add . && git commit -m "Critical fix for production issue"
git push origin hotfix/critical-fix
gh pr create --title "HOTFIX: Critical fix" --body "Urgent production fix"
# ... merge immediately ...
git checkout main && git pull
git tag v1.1.1 && git push origin v1.1.1

# 🔙 Rollback workflow
git revert HEAD  # Reverts the latest commit
git push origin main  # ArgoCD automatically deploys the rollback

# 🏷️ Version tag patterns
git tag v1.0.0    # Major release
git tag v1.1.0    # Minor release (new features)
git tag v1.0.1    # Patch release (bug fixes)
```

### Common Change Scenarios

#### **Update Application Version**
```bash
# The workflow automatically updates image tags, but you can also do it manually:
sed -i 's/tag: "v1.0.0"/tag: "v1.1.0"/' helm/app/values.yaml
git add helm/app/values.yaml
git commit -m "Update application to v1.1.0"
```

#### **Scale Application**
```bash
# Increase replica count
sed -i 's/replicaCount: 6/replicaCount: 10/' helm/app/values.yaml

# Update autoscaling limits  
sed -i 's/maxReplicas: 20/maxReplicas: 50/' helm/app/values.yaml

git add helm/app/values.yaml
git commit -m "Scale application for increased load"
```

#### **Update Configuration**
```bash
# Change database provider
sed -i 's/provider: "SqlServer"/provider: "Redis"/' helm/app/values.yaml

# Enable distributed caching
sed -i 's/enabled: false/enabled: true/' helm/app/values.yaml

git add helm/app/values.yaml  
git commit -m "Switch to Redis backend and enable caching"
```

#### **Emergency Rollback**
```bash
# Quick rollback to previous version
git revert HEAD
git push origin main
# ArgoCD automatically deploys the previous version

# Or rollback to specific version
git revert <commit-hash>
git push origin main
```

## 🏗️ Infrastructure Management

### Deploy Infrastructure

Use the GitHub Actions workflow to manage your AKS cluster:

1. **Go to Actions tab** in your GitHub repository
2. **Run "Deploy Infrastructure"** workflow
3. **Select options**:
   - **Action**: `plan` (to preview changes), `apply` (to deploy), or `destroy` (to cleanup)
   - **Environment**: `demo`, `staging`, or `production`

### Infrastructure Workflow Features

- ✅ **Terraform Plan/Apply/Destroy**: Complete infrastructure lifecycle
- ✅ **Multiple Environments**: Support for demo, staging, production  
- ✅ **State Management**: Uses Azure Storage for Terraform state
- ✅ **Security**: Uses Azure Service Principal authentication
- ✅ **Validation**: Runs terraform fmt and validate checks
- ✅ **ArgoCD Setup**: Automatically installs and configures ArgoCD
- ✅ **Application Bootstrap**: Deploys app-of-apps pattern

### Post-Deployment

After successful infrastructure deployment, the workflow provides:

- **ArgoCD admin password** in the workflow summary
- **kubectl access commands** to connect to your cluster
- **ArgoCD port-forward instructions** to access the UI
- **Application status** showing deployed applications

### Infrastructure Cleanup

To destroy the infrastructure:
```bash
# Run the workflow with destroy action
# Go to Actions → Deploy Infrastructure
# Select: Action = destroy, Environment = demo
```

**Warning**: This will delete the entire AKS cluster and all applications!

## Repository Structure

```
├── argocd-apps/                    # ArgoCD Application definitions
│   └── reliability-demo.yaml      # Main application configuration
├── helm/                          # Helm charts
│   └── app/                       # Main application chart
│       ├── Chart.yaml             # Chart metadata and dependencies
│       ├── values.yaml            # Default configuration values
│       ├── templates/             # Kubernetes resource templates
│       │   ├── web-deployment.yaml
│       │   ├── web-service.yaml
│       │   ├── web-hpa.yaml
│       │   ├── web-pdb.yaml
│       │   ├── worker-deployment.yaml
│       │   ├── worker-hpa.yaml
│       │   ├── worker-pdb.yaml
│       │   └── _helpers.tpl
│       └── charts/                # Subcharts
│           └── sqlserver/         # SQL Server subchart
└── README.md                      # This file
```

## ArgoCD App-of-Apps Pattern

This repository uses the App-of-Apps pattern where ArgoCD manages applications by reading configurations from Git. The Terraform infrastructure automatically deploys an `app-of-apps` application that monitors the `argocd-apps/` directory.

### How it Works

1. **Infrastructure Deployment**: Terraform creates AKS cluster and installs ArgoCD
2. **App-of-Apps Bootstrap**: ArgoCD creates an application pointing to this repository's `argocd-apps/` directory
3. **Application Discovery**: ArgoCD automatically deploys any applications defined in `argocd-apps/`
4. **Continuous Deployment**: Git commits trigger automatic deployments

## Application Configuration

### Reliability Demo Application

The main application is defined in `argocd-apps/reliability-demo.yaml` and deploys:

- **Web API**: Customer management REST API with health checks
- **Worker**: Background message processing service  
- **SQL Server**: Database backend with persistent storage
- **Redis**: Caching and messaging backend

### Key GitOps Features

- **Automatic Sync**: Changes to this repository trigger deployments within seconds
- **Self-Healing**: ArgoCD reverts manual kubectl changes to match Git state
- **Health Monitoring**: Application health is continuously monitored
- **Rollback**: Git revert operations automatically rollback deployments

## Helm Chart Configuration

### Production-Ready Features

The Helm chart includes enterprise-grade configurations:

```yaml
# High Availability
web:
  replicaCount: 6
  podDisruptionBudget:
    enabled: true
    minAvailable: 50%

# Auto-Scaling  
autoscaling:
  enabled: true
  minReplicas: 6
  maxReplicas: 20
  targetCPUUtilizationPercentage: 80

# Health Checks
livenessProbe:
  httpGet:
    path: /api/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

# Resource Management
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi" 
    cpu: "500m"

# Security
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

### Configuration Management

Environment-specific configurations are managed through Helm values:

- **Development**: Lower resource limits, faster health checks
- **Staging**: Production-like configuration with debug logging
- **Production**: Full resource allocation, optimized for performance

## Making Changes

### Application Updates

To update the application version:

```bash
# Edit values.yaml
sed -i 's/tag: "m1-01"/tag: "m1-02"/' helm/app/values.yaml

# Commit and push
git add helm/app/values.yaml
git commit -m "Update application to version m1-02"
git push
```

ArgoCD will detect the change and deploy automatically.

### Configuration Changes

To modify application configuration:

```bash
# Edit configuration in values.yaml
vim helm/app/values.yaml

# Commit changes
git add helm/app/values.yaml
git commit -m "Update failure simulation rates"
git push
```

### Rollback

To rollback to a previous version:

```bash
# Revert the commit
git revert HEAD
git push
```

ArgoCD will automatically rollback the deployment.

## Monitoring and Observability

### ArgoCD Dashboard

Access the ArgoCD UI to monitor deployments:

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access https://localhost:8080
# Username: admin
```

### Application Health

ArgoCD provides real-time visibility into:

- **Sync Status**: Whether deployed resources match Git
- **Health Status**: Application health based on Kubernetes probes
- **Resource Status**: Individual resource deployment status
- **Events**: Deployment history and events

## Benefits Over Manual Deployment

| Aspect | Manual Process | GitOps with ArgoCD |
|--------|---------------|-------------------|
| **Deployment Time** | 45-60 minutes | 2-5 minutes |
| **Error Rate** | ~40% | <1% |
| **Rollback Time** | 2-4 hours | 30 seconds |
| **Configuration Drift** | Common | Impossible |
| **Audit Trail** | Scattered | Complete Git history |
| **Multi-Environment** | Error-prone | Template-based |

## Security Best Practices

### GitOps Security Model

- **Single Source of Truth**: All changes must go through Git
- **Immutable Infrastructure**: No direct cluster modifications
- **Audit Trail**: Complete history of all changes
- **Role-Based Access**: Git permissions control deployment access

### Application Security

- **Non-Root Containers**: Applications run as non-privileged users
- **Resource Limits**: Prevents resource exhaustion attacks
- **Network Policies**: Controls inter-service communication
- **Secret Management**: Sensitive data stored in Kubernetes secrets

## Troubleshooting

### Common Issues

**GitHub Actions Workflow Failing**
```bash
# Check if GHCR permissions are set correctly
# Go to Settings → Actions → General → Workflow permissions
# Ensure "Read and write permissions" is selected

# Verify package creation permissions
# Settings → General → Features → Enable Packages

# Check workflow logs for specific errors
```

**Container Registry Access Issues**
```bash
# If Kubernetes can't pull images, check:
# 1. Package visibility (make public or add imagePullSecrets)
# 2. Image names match exactly between values.yaml and GHCR
# 3. Tags are properly formatted (v1.2.3 not 1.2.3)

# Test production image pull manually
docker pull ghcr.io/YOUR-USERNAME/YOUR-REPO/reliability-demo:v1.0.0

# Test staging image pull manually
docker pull ghcr.io/YOUR-USERNAME/YOUR-REPO-staging/reliability-demo:pr-123
```

**Application Not Syncing**
```bash
# Check ArgoCD application status
kubectl get application reliability-demo -n argocd -o yaml

# Check if repository URL is correct in ArgoCD
kubectl describe application reliability-demo -n argocd

# Force sync if needed
kubectl patch application reliability-demo -n argocd -p '{"operation":{"sync":{}}}' --type merge
```

**Pod Startup Issues**
```bash
# Check pod logs
kubectl logs -n reliability-demo deployment/reliability-demo-web

# Check events for image pull errors
kubectl get events -n reliability-demo --sort-by='.lastTimestamp'

# Verify image exists in GHCR
curl -H "Authorization: Bearer $(gh auth token)" \
  https://ghcr.io/v2/YOUR-USERNAME/YOUR-REPO/reliability-demo/tags/list
```

**Health Check Failures**
```bash
# Test health endpoint manually
kubectl port-forward -n reliability-demo svc/reliability-demo-web 8080:8080
curl http://localhost:8080/api/health
```

### GitHub Actions Debugging

**Workflow Not Triggering**
- Ensure tags follow semantic versioning: `v1.2.3` (with 'v' prefix)
- Check if branch protection rules are preventing the workflow
- Verify the tag was pushed: `git push origin v1.2.3`

**Image Build Failures**
- Check if Dockerfile paths are correct in workflow
- Verify source code structure matches expected paths
- Review build logs for dependency or compilation errors

**Permission Denied Errors**
- Confirm workflow permissions are set to "Read and write"
- Check if organization settings override repository settings
- Verify GITHUB_TOKEN has necessary scopes

### Repository Configuration Checklist

✅ **GHCR Enabled**: Settings → General → Features → Packages  
✅ **Workflow Permissions**: Settings → Actions → General → Read and write permissions  
✅ **Branch Protection**: Settings → Branches → Add rule for main  
✅ **Image Paths Updated**: Check helm/app/values.yaml and workflows  
✅ **Semantic Versioning**: Use v1.2.3 format for tags  

## Contributing

1. Fork this repository
2. Create a feature branch
3. Make changes to Helm values or templates
4. Test changes in development environment
5. Submit pull request
6. Changes are automatically deployed after merge

## Related Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Health Checks](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [GitOps Principles](https://opengitops.dev/)