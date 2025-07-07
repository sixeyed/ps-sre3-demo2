# Manual Deployment Runbook

**Version:** 1.2  
**Last Updated:** 2024-01-15  
**Owner:** Development Team

This runbook documents the manual deployment process for the reliability-demo application to test environments. Follow these steps in order to deploy code changes.

## Prerequisites

- Test Kubernetes cluster configured in kubectl context
- PowerShell 7+ installed
- Docker Desktop running
- Access to test.registry:5001 container registry
- Deployment manifests in `manifests/` folder

## Deployment Steps

### Step 1: Verify Test Cluster Connection

```powershell
# Connect to test cluster
kubectl get nodes

# Verify current application status  
kubectl get deployments -n reliability-demo
kubectl get pods -n reliability-demo
```

**Expected Result:** 3 worker nodes showing Ready status, existing deployments running

### Step 2: Build and Tag Container Image

```powershell
# Generate timestamp tag for new image
$timestamp = Get-Date -Format "yyyy-MM-dd-HH"
$imageTag = "test.registry:5001/reliability-demo:$timestamp"

Write-Host "Building web image with tag: $imageTag"
Push-Location ../../src

# Build new container image
docker build -t $imageTag -f ReliabilityDemo/Dockerfile .

# Push to test registry
docker push $imageTag

Write-Host "Image pushed successfully: $imageTag"
Pop-Location
```

### Step 3: Update Deployment Manifest

```powershell
# Check you can see all the mainifests
ls manifests/

# Update the final manifest with new image tag
$manifestPath = "manifests/customer-api-final.yaml"
$manifest = Get-Content $manifestPath

# Replace image tag (find the image line and update)
$manifest = $manifest -replace "image: test\.registry:5001/reliability-demo:.*", "image: $imageTag"

# Save updated manifest
$manifest | Set-Content $manifestPath

Write-Host "Updated manifest with image: $imageTag"
```

Check the manifest before you apply!

> [customer-api-final.yaml](manifests/customer-api-final.yaml)

### Step 4: Apply Deployment

```powershell
# Apply the updated manifest
kubectl apply -f $manifestPath
```

> Monitor the rollout

### Step 5: Check it works!

Browse to the app: 

> http://localhost:8080

Check the logs (thanks Carlos!):

> http://localhost:3000/explore?schemaVersion=1&panes=%7B%22zwl%22:%7B%22datasource%22:%22P8E80F9AEF21F6940%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bnamespace%3D%5C%22sre3-m1%5C%22%7D%20%7C%3D%20%60%60%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22P8E80F9AEF21F6940%22%7D,%22editorMode%22:%22builder%22%7D%5D,%22range%22:%7B%22from%22:%22now-5m%22,%22to%22:%22now%22%7D%7D%7D&orgId=1

Any issues, see troubleshooting below.

## Troubleshooting

### Common Issues

**Pods stuck in Pending:**
- Check resource requests vs cluster capacity
- Verify nodes have sufficient CPU/memory

**Application not responding:**
- Check ConfigMap for correct connection strings
- Verify Redis and SQL Server pods are running
- Review application logs for errors

**Image pull errors:**
- Verify image exists in registry: `docker pull $imageTag`
- Check registry connectivity from cluster

### Resource Requirements

Current manifest ([`customer-api-final.yaml`](manifests/customer-api-final.yaml)) specifies:
- **Memory Request:** 2Gi (may need to reduce for test cluster)
- **CPU Request:** 1000m (may need to reduce for test cluster)  
- **Replicas:** 5 (may exceed cluster capacity)

### Configuration Dependencies

The [`customer-api-config.yaml`](manifests/customer-api-config.yaml) ConfigMap must have:
- Redis connection: `redis:6379` (not localhost)
- SQL Server connection: `sqlserver:1433` (not localhost)

## Post-Deployment Checklist

- [ ] All pods in Running state
- [ ] Application health endpoint responding
- [ ] Web interface accessible
- [ ] Customer operations working (create/read/update/delete)
- [ ] No error logs in application pods

## Notes

- Deployment typically takes 5-10 minutes
- Resource constraints may require manifest adjustments
- No automated health checks - manual verification required
- Rollback process is manual and time-consuming
- Scaling limited by cluster capacity

## Known Limitations

1. **Manual process** - Each step requires human intervention
2. **No health checks** - Kubernetes can't detect application failures
3. **Resource mismatches** - Production specs don't fit test environment
4. **Configuration drift** - Easy to forget environment-specific settings
5. **No automated rollback** - Manual process to revert failed deployments
6. **Timestamp versioning** - Difficult to track which version was previous

---

*This runbook will be replaced with automated GitOps deployment in the next iteration.*