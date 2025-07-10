# Demo 1: Static Infrastructure and Scaling Problems

## Pre-Demo Setup

- Deploy AKS cluster with static configuration
- Deploy application with fixed pod counts
- Ensure monitoring stack is available

## Demo

### 1. Show Infrastructure Costs

Connect to the production AKS cluster:

```powershell
# Check cluster status
kubectl get nodes

# Show node resources
kubectl top nodes

# Check current pod deployment
kubectl get deployments -n reliability-demo
```

**Azure Cost Management Portal:**
- Show current burn rate
- Display projected monthly costs
- Highlight compute-only costs (not including storage/networking)

### 2. Resource Utilization Metrics

Open monitoring dashboard:

> http://localhost:3000

**Key metrics to highlight:**
- CPU utilization: ~5-10% across all nodes
- Memory usage: Even lower than CPU
- Node count: Fixed regardless of load
- Pod count: Static from deployment specs

Show pod resource requests:

```powershell
# Check pod resource requests
kubectl describe deployment customer-api-web -n reliability-demo | grep -A 5 "Limits\|Requests"

# Show current pod count
kubectl get pods -n reliability-demo | grep -c "customer-api"
```

### 3. Run K6 Load Tests

Start the K6 test suite:

```powershell
# Deploy K6 tests
kubectl apply -f k6-tests.yaml

# Monitor test progress
kubectl logs -f job/k6-tests -n reliability-demo
```

**Test sequence:**
1. **Soak Test**: Sustained read traffic for 5 minutes
2. **Load Test**: Heavy write operations for 3 minutes  
3. **Spike Test**: Sudden traffic surge simulation

### 4. Analyze Test Results

#### Soak Test Results
- CPU remains in single digits
- Memory flat throughout
- Response times stable
- Infrastructure vastly oversized for normal load

#### Load Test Results  
- CPU increases but stays < 20%
- Write operations stress message queues
- Worker pods can't keep up despite available resources
- Pod count bottleneck emerges

#### Spike Test Results
- System fails despite 50% CPU headroom
- Error rates climb rapidly
- Response times spike
- Pods overwhelmed at connection level

### 5. Investigate Bottlenecks

Check pod scaling:

```powershell
# Show fixed pod counts
kubectl get deployment customer-api-web -n reliability-demo -o yaml | grep replicas

# Check HPA status (none configured)
kubectl get hpa -n reliability-demo

# View message queue backup
kubectl exec -it redis-0 -n reliability-demo -- redis-cli llen customer_operations
```

**Key findings:**
- Fixed pod count regardless of load
- No horizontal pod autoscaling configured
- Each pod has connection limits
- Message workers can't scale with queue depth

### 6. Show Cost Impact

Return to idle state:

```powershell
# Stop load tests
kubectl delete job k6-tests -n reliability-demo

# Watch metrics return to baseline
kubectl top nodes --watch
```

**Cost analysis:**
- Resources return to ~5% utilization
- Monthly cost remains unchanged
- Annual projection: $XX,XXX
- Most spending on idle capacity

### 7. The Fundamental Problem

Demonstrate the static infrastructure trap:

1. **Over-provisioned**: Paying for unused resources 95% of the time
2. **Under-performing**: Still fails during actual load spikes
3. **No elasticity**: Can't scale pods even with available node resources
4. **Manual intervention**: Scaling requires human action during incidents

## Common Issues

### Pod Resource Limits
Current configuration uses production-like requests:
- CPU Request: 1000m per pod
- Memory Request: 2Gi per pod
- No autoscaling configured

### Message Queue Bottleneck
- Fixed worker pod count
- Messages accumulate faster than processing
- No queue-depth-based scaling

### Connection Limits
- Each pod handles limited concurrent connections
- Load balancer can't compensate for pod limits
- More pods needed, not more CPU

## Next Steps

This demo shows why static infrastructure fails:
- Expensive when idle
- Inadequate when loaded
- No automatic adaptation

The next demo will show SRE team's solution with:
- Horizontal Pod Autoscaling (HPA)
- Cluster autoscaling
- Metrics-based scaling
- Cost optimization