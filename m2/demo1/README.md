# Module 2 Clip 02 - Development Team Deployment Demo Steps

This demo shows how the development team currently deploys their application to test environments. The process works for their needs but isn't ready for production scale.

## Prerequisites
- Test Kubernetes cluster (manually created, running older version)
- kubectl configured with test cluster credentials
- Docker registry with test images
- Shared folder with deployment manifests

## Demo Steps

### 1. Connect to Test Cluster
```bash
# Show the manually created test cluster
kubectl get nodes
# Note: 3 worker nodes, older Kubernetes version

# Show current deployments
kubectl get deployments -n reliability-demo
```

### 2. Build and Push Container Image
```bash
# Build with timestamp tag
docker build -t testregistry.azurecr.io/customer-api:2024-01-15-1430 .
docker push testregistry.azurecr.io/customer-api:2024-01-15-1430
```

### 3. Update Kubernetes Manifests
```bash
# Show shared folder with multiple versions
ls manifests/
# customer-api-v1.yaml
# customer-api-v2.yaml  
# customer-api-final.yaml

# Edit the "final" version with new image tag
vi manifests/customer-api-final.yaml
# Update image: testregistry.azurecr.io/customer-api:2024-01-15-1430
```

### 4. Apply Deployment
```bash
# Apply the manifest
kubectl apply -f manifests/customer-api-final.yaml

# Monitor rollout (manual process)
# Run k9s or repeatedly check pods
kubectl get pods -n reliability-demo -w
```

### 5. Deployment Issues - Resource Constraints
```bash
# Pods stuck in pending
kubectl describe pod customer-api-xxxxx -n reliability-demo
# Events: Insufficient memory

# Fix resource requests in YAML
vi manifests/customer-api-final.yaml
# Reduce memory requests for test environment

# Reapply
kubectl apply -f manifests/customer-api-final.yaml
```

### 6. Verify Deployment
```bash
# Browse to application
# Show it's partially working

# Check logs for errors
kubectl logs -n reliability-demo deployment/customer-api
# Error: Cannot connect to Redis at localhost:6379
```

### 7. Fix Configuration Error
```bash
# Update ConfigMap with correct Redis host
kubectl edit configmap customer-api-config -n reliability-demo
# Change Redis host from localhost to redis-master

# Restart pods
kubectl rollout restart deployment customer-api -n reliability-demo
```

### 8. Demonstrate Scaling Issues
```bash
# Try to scale to 10 replicas
kubectl scale deployment customer-api --replicas=10 -n reliability-demo

# Show pods stuck in pending
kubectl get pods -n reliability-demo
# Multiple pods in Pending state - not enough nodes
# No autoscaling configured
```

### 9. Show Missing Health Checks
```bash
# Deploy broken image
kubectl set image deployment/customer-api customer-api=testregistry.azurecr.io/customer-api:broken-test -n reliability-demo

# Kubernetes updates all pods even though app crashes
kubectl get pods -n reliability-demo
# Pods show Running but app is broken

# Manual rollback required
kubectl rollout undo deployment customer-api -n reliability-demo
```

### 10. Total Time and Issues
- Deployment time: ~10 minutes (when it goes smoothly)
- Multiple manual steps prone to errors
- No automated rollback
- No health checks
- No self-healing capabilities

## Key Problems Demonstrated
1. **Manual cluster management** - Old Kubernetes version, no documentation
2. **Timestamp versioning** - No semantic versioning or Git tags
3. **Shared folder chaos** - Multiple YAML versions, unclear which is current
4. **No dependency management** - Redis connection not validated
5. **Resource mismatches** - Production specs in test environment
6. **Missing health checks** - Kubernetes can't detect broken deployments
7. **No autoscaling** - Manual intervention required for capacity
8. **Configuration errors** - Easy to forget environment-specific settings
9. **No rollback strategy** - Just "redeploy previous version" (which one?)
10. **No self-healing** - Failed pods require manual intervention