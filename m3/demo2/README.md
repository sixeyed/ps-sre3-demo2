# Module 3 Demo 2 - Dynamic Scaling with KEDA

This demo transforms the static, over-provisioned infrastructure from Demo 1 into a dynamic system that scales based on actual demand using KEDA (Kubernetes Event-Driven Autoscaling). The same K6 load tests that failed in Demo 1 will now pass by leveraging autoscaling and right-sized infrastructure.

## 🎯 Demo Goals

- **Transform static infrastructure** into dynamic, event-driven autoscaling
- **Right-size the AKS cluster** with smaller nodes and autoscaling enabled  
- **Deploy KEDA** for application-level autoscaling based on metrics
- **Run the same K6 tests** from Demo 1 and demonstrate they now pass
- **Show cost reduction** while improving reliability and performance

## 🏗️ Architecture Changes

### Infrastructure (m3demo2 Profile)
- **Smaller VM sizes**: D4 instances (4 vCPUs, 16GB RAM) instead of D8
- **Node autoscaling**: 2-7 nodes per pool (min for availability, max for cost control)
- **Better scaling granularity**: Smaller increments vs. giant steps
- **Quick scale-up, gradual scale-down**: Avoid flapping while maintaining responsiveness

### Application Autoscaling with KEDA
- **Web pods**: Scale based on CPU and memory utilization
- **Worker pods**: Scale based on Redis queue depth
- **CPU/Memory HPA**: Traditional horizontal pod autoscaling as baseline
- **Event-driven scaling**: Proactive scaling before resource exhaustion

## 🚀 Demo Flow

### 1. Infrastructure Setup

Deploy the m3demo2 profile with dynamic scaling:

```powershell
# Deploy with m3demo2 profile (autoscaling enabled)
./setup.ps1 -Profile m3demo2
```

**Key differences from Demo 1**:
- Starts with 2 small nodes (minimal baseline)
- Node pools configured for autoscaling (2-7 nodes)
- D4 VMs instead of D8 for better granularity
- Projected cost: Hundreds $/month vs. thousands in Demo 1

### 2. KEDA Deployment

KEDA is automatically deployed via ArgoCD:
- **KEDA Operator**: Event-driven autoscaling controller
- **ScaledObjects**: Define scaling triggers for web and worker pods
- **Metrics Sources**: HTTP metrics, Redis queue depth, CPU/memory

### 3. Application Configuration

**Web Pods (Resource-based scaling)**:
- Scale on CPU utilization (60%) and memory utilization (70%)
- Target: Maintain responsive performance under load
- Range: 2-10 replicas

**Worker Pods (Queue-based scaling)**:
- Scale on Redis queue depth
- Target: Keep queue length minimal  
- Range: 1-5 replicas

### 4. Load Testing with K6

Run the same test suite from Demo 1:

```powershell
# Run the same tests that failed in Demo 1
./run-k6-tests.ps1
```

**Test Sequence** (same as Demo 1):
1. **Soak Test** (10 min, 40 VUs): Sustained read-heavy traffic
2. **Load Test** (5 min, 70 VUs): Write-focused operations  
3. **Spike Test** (5 min, 600 VUs): Sudden traffic surge

## 📊 Expected Results

### Soak Test (Read-Heavy)
- **KEDA Response**: HTTP metrics trigger web pod scaling
- **Infrastructure**: Existing nodes have capacity, no new nodes needed
- **Outcome**: ✅ **PASS** - Smooth handling of sustained load

### Load Test (Write-Heavy)  
- **KEDA Response**: Redis queue depth triggers worker pod scaling
- **Infrastructure**: Cluster autoscaler provisions new nodes for additional pods
- **Outcome**: ✅ **PASS** - No queue backlog, distributed processing

### Spike Test (Extreme Load)
- **KEDA Response**: Rapid web pod scaling on HTTP metrics spike
- **Infrastructure**: Multiple new nodes provisioned automatically
- **Outcome**: ✅ **PASS** - All 600 users handled successfully
- **Key**: More pods = more aggregate capacity (connections, network, etc.)

### Post-Test Behavior
- **Automatic scale-down**: As load drops, KEDA reduces pod counts
- **Node removal**: Empty nodes marked for removal and terminated
- **Cost optimization**: Return to minimal baseline automatically

## 💰 Cost Analysis

### Demo 1 (Static) vs Demo 2 (Dynamic)

| Aspect | Demo 1 (Static) | Demo 2 (Dynamic) |
|--------|----------------|------------------|
| **Baseline Nodes** | 9 × D8 (always on) | 2 × D4 (baseline) |
| **Peak Nodes** | 9 × D8 (always on) | 7 × D4 (1 hour spike) |
| **Monthly Cost** | $3,000+ (constant) | $400-600 (variable) |
| **Spike Handling** | ❌ Fails | ✅ Succeeds |
| **Resource Utilization** | ~20% (waste) | ~70% (efficient) |

### Key Benefits
- **85% cost reduction** compared to static infrastructure
- **Better performance** under all load patterns
- **Higher reliability** through elastic capacity
- **No manual intervention** required

## 🔧 Technical Implementation

### KEDA Configuration

**Web Pod ScaledObject**:
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: web-scaler
spec:
  scaleTargetRef:
    name: reliability-demo
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: http_requests_per_second
      threshold: '100'
      query: 'sum(rate(http_requests_total[2m]))'
```

**Worker Pod ScaledObject**:
```yaml
apiVersion: keda.sh/v1alpha1  
kind: ScaledObject
metadata:
  name: worker-scaler
spec:
  scaleTargetRef:
    name: reliability-demo-worker
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
  - type: redis
    metadata:
      address: redis:6379
      listName: customer_operations
      listLength: '5'
```

### Cluster Autoscaler Configuration

```hcl
# Terraform configuration for autoscaling
enable_auto_scaling = true
node_count         = 2  # baseline
min_node_count     = 2  # availability 
max_node_count     = 7  # cost control

# Smaller VMs for better granularity
node_vm_size = "Standard_D4s_v5"  # 4 vCPUs, 16GB RAM

# Autoscaling profile
scale_down_delay_after_add    = "10m"
scale_down_unneeded_time      = "10m"  
scale_down_utilization_threshold = 0.5
```

## 📈 Monitoring and Observability

### Key Metrics to Watch
- **Pod Scaling Events**: KEDA scaling decisions
- **Node Scaling Events**: Cluster autoscaler actions  
- **Queue Depth**: Redis queue length over time
- **HTTP Metrics**: Request rate and response times
- **Resource Utilization**: CPU/memory across nodes
- **Cost Tracking**: Real-time infrastructure costs

### Grafana Dashboards
- **KEDA Scaling Dashboard**: Scaling events and metrics
- **Cluster Autoscaler Dashboard**: Node lifecycle events
- **Application Performance**: Response times, throughput
- **Cost Analysis**: Projected vs. actual costs

## 🎭 Demo Script Points

### Opening (Infrastructure Comparison)
- Show Terraform configuration differences (D4 vs D8, autoscaling enabled)
- Highlight cost projections: hundreds vs. thousands per month
- Demonstrate initial state: 2 small nodes vs. 9 large nodes

### During Tests (Real-time Scaling)
- **Soak Test**: Watch KEDA detect HTTP metrics and scale web pods
- **Load Test**: Show Redis queue scaling and new node provisioning  
- **Spike Test**: Demonstrate rapid scaling handling 600 users successfully

### Post-Tests (Automatic Cleanup)
- Show pods scaling down as load drops
- Watch nodes being marked for removal
- Highlight return to minimal baseline cost

### Wrap-up (SRE Philosophy)
- **Define behaviors, not sizes**: Policies over fixed configurations
- **Scale to reality, not guesses**: Data-driven capacity management
- **Reliability through elasticity**: Adapt to any traffic pattern

## 🔄 Cleanup

```powershell
# Clean up all resources
./cleanup.ps1 -Profile m3demo2
```

## 📚 Key Takeaways

1. **Dynamic scaling** dramatically reduces costs while improving reliability
2. **KEDA** enables proactive, event-driven autoscaling before resource exhaustion
3. **Right-sized infrastructure** with autoscaling beats over-provisioned static resources
4. **SRE approach**: Set policies and behaviors, let the system discover its needs
5. **Cost optimization** happens automatically without sacrificing performance

---

*This demo showcases the transformation from static waste to dynamic efficiency - the core of modern SRE capacity management.*