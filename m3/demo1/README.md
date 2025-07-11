# Demo 1: Static Infrastructure Problems

## Pre-Demo Setup

- Deploy m3demo1 infrastructure profile with oversized static configuration
- Run K6 tests to demonstrate failure at scale

## Demo

### Infrastructure Profile

- [terraform/profiles/m3demo1.tfvars](../../terraform/profiles/m3demo1.tfvars) - Oversized D8 VMs, no autoscaling

- [script.ps1](script.ps1) - Infrastructure deployment script

### Helm Configuration

- [helm/app/values.yaml](../../helm/app/values.yaml) - Static pod counts, no HPA

- [helm/app/templates/web-deployment.yaml](../../helm/app/templates/web-deployment.yaml) - Fixed replicas

### Deploy Infrastructure

```powershell
# Deploy with m3demo1 profile  
./setup.ps1
```

### Show Resource Waste

```powershell
# Check oversized nodes
kubectl get nodes

# Show low utilization
kubectl top nodes

# View static deployments
kubectl get deployments -n reliability-demo
```

**Findings:**
- 3x D8 VMs (8 CPU, 32GB) always running
- ~5-10% CPU utilization most of the time
- High monthly costs for idle capacity

### Run K6 Load Tests

```powershell
# Run load tests
./run-k6-tests.ps1
```

**Test Sequence:**
- Soak Test (10m, 40 VUs): ✅ PASS
- Load Test (5m, 70 VUs): ✅ PASS  
- Spike Test (5m, 600 VUs): ❌ **FAIL**

### Analyze Failure

```powershell
# Check scaling status
kubectl get hpa -n reliability-demo  # No HPA configured

# View pod limits 
kubectl describe deployment reliability-demo -n reliability-demo
```

**Root Cause:**
- Fixed pod count regardless of load
- Each pod has connection limits
- No horizontal scaling configured
- 600 users overwhelm static pod count

### Cost Analysis

```powershell
# Return to idle state
kubectl top nodes
```

**Cost Impact:**
- Resources return to ~5% utilization
- Monthly cost unchanged despite failure
- Paying for unused capacity 95% of time

## Key Problems

- **Over-provisioned**: Expensive idle infrastructure
- **Under-performing**: Fails during load spikes  
- **No elasticity**: Can't scale pods automatically
- **Manual intervention**: Requires human action during incidents

## Next Steps

Demo 2 will show the SRE solution:
- KEDA autoscaling fixes the spike test failure
- Dynamic scaling reduces costs by 85%
- Same tests pass with right-sized infrastructure