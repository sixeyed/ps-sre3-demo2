# Demo 2: Dynamic Scaling with KEDA

## Pre-Demo Setup

- Deploy m3demo2 infrastructure profile with KEDA autoscaling
- Same K6 tests from Demo 1 will now pass

## Demo

### Infrastructure Profile

- [terraform/profiles/m3demo2.tfvars](../../terraform/profiles/m3demo2.tfvars) - D4 VMs with 2-7 node autoscaling

- [terraform/main.tf](../../terraform/main.tf) - KEDA module deployment

### KEDA Configuration

- [helm/app/values-m3demo2.yaml](../../helm/app/values-m3demo2.yaml) - ScaledObjects and resource limits

- [helm/app/templates/web-scaledobject.yaml](../../helm/app/templates/web-scaledobject.yaml) - HTTP metrics scaling

- [helm/app/templates/worker-scaledobject.yaml](../../helm/app/templates/worker-scaledobject.yaml) - Redis queue scaling

### OpenTelemetry Metrics

- [src/ReliabilityDemo/Program.cs](../../src/ReliabilityDemo/Program.cs) - Prometheus metrics endpoint

- [helm/lgtm/Chart.yaml](../../helm/lgtm/Chart.yaml) - Prometheus dependency

### Deploy Infrastructure

```powershell
# Deploy with m3demo2 profile
./setup.ps1
```

### Run Same Tests from Demo 1

```powershell
# Same K6 tests, now with KEDA autoscaling
./run-k6-tests-demo1.ps1
```

**Expected Results:**
- Soak Test (40 VUs): ✅ PASS (HTTP scaling)
- Load Test (70 VUs): ✅ PASS (Queue scaling)  
- Spike Test (600 VUs): ✅ PASS (Rapid scaling)

### Monitor Scaling Events

```powershell
# Watch KEDA scaling
kubectl get scaledobjects -n reliability-demo -w

# View scaling events
kubectl get events -n reliability-demo --sort-by=.metadata.creationTimestamp
```

### Cleanup

```powershell
./cleanup.ps1
```

## Key Results

- **Same 600-user spike test that failed in Demo 1 now passes**
- **85% cost reduction** vs static infrastructure  
- **224,670 total iterations** completed successfully
- **Dynamic scaling** handles any load pattern automatically