# Demo 2: Production-Ready GitOps

## Pre-Demo Setup

- Deploy infra and baseline build with GitHub Actions

## Demo 

### Check Infrastracture Deployment

Latest workflow run:

> https://github.com/sixeyed/ps-sre3-demo2/actions/runs/16178453579

### Terraform AKS Config

- [aks/main.tf](../../terraform/modules/aks/main.tf) - Zones and patch upgrades

- [aks/variables.tf](../../terraform/modules/aks/variables.tf) - Node size and scaling

### Helm Chart Improvements


- [helm/app/templates/web-deployment.yaml](../../helm/app/templates/web-deployment.yaml) - Container probes

- [helm/app/values.yaml](../../helm/app/values.yaml) - Probe configuration and autoscaling

- [helm/app/templates/web-hpa.yaml](../../helm/app/templates/web-hpa.yaml) - Aautoscaling configuration

### ArgoCD Configuration

- [terraform/modules/argocd/main.tf](../../terraform/modules/argocd/main.tf) - Helm release for Argo

- [terraform/charts/argocd-apps/templates/reliability-demo-app.yaml](../../terraform/charts/argocd-apps/templates/reliability-demo-app.yaml) - Destination and SyncPolicy for app

### Demonstrate CI/CD Workflow

Workflow:

- [workflows/build-pr.yml](../../.github/workflows/build-pr.yml) - Build, lint, scan, push to staging

Create PR from demo branch:

> https://github.com/sixeyed/ps-sre3-demo2

Check build.

### Deploy with Version Tag

- [workflows/release.yml](../../.github/workflows/release.yml) - Promote image to prod repository, update version in Helm

```powershell
# Switch back to main and pull
git checkout main; git pull github main

# Tag and push
git tag v0.9.7; git push github v0.9.7
```

**Monitor in GitHub Actions:**
- Watch staging images get promoted to production repository (sixeyed)
- Helm chart values.yaml gets updated with new version and ACR registry
- Changes committed back to main branch
- GitHub release created

### Watch ArgoCD Sync

> http://108.141.126.221

### Demonstrate Self-Healing

In K9s:

- delete a web Pod; new Pod created and goes through Readiness checks

- delete web Deployment; Argo recreates

- update image to Alpine in [templates/web-deployment.yaml](../../helm/app/templates/web-deployment.yaml)

```powershell
git add helm/app/templates/web-deployment.yaml
git commit -m "Deploy broken version for testing"
git push github main

git tag v0.9.8
git push github v0.9.8
```

Rollback:

```powershell
# Revert the broken change
git revert HEAD --no-edit
git push origin main
```
