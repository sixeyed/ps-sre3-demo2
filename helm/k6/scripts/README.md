# K6 Load Testing Scripts

This directory contains K6 JavaScript test scripts for demonstrating system behavior under different load conditions. These scripts are crucial for the demo flow to show performance differences between baseline and resilient configurations.

## Demo Scripts

- **customer-load-test.js** - Standard load testing with gradual user ramp-up
  - Creates and retrieves customers with realistic load patterns
  - Used to expose baseline performance issues
  
- **customer-spike-test.js** - Spike testing with sudden load increases
  - Tests system behavior under traffic bursts
  - Demonstrates failure modes and recovery patterns
  
- **customer-soak-test.js** - Extended duration testing with constant load
  - Tests system stability over time
  - Validates memory leaks and resource exhaustion

## Demo Usage

### Phase 1: Baseline Testing (Cache/Messaging Disabled)
```bash
# Deploy with baseline configuration
helm install reliability-demo ../app --set config.distributedCache.enabled=false --set config.messaging.enabled=false

# Run load test to show performance issues
helm install k6-load . --set testType=load --wait
kubectl logs job/k6-load

# Observe timeouts and slow responses in logs
```

### Phase 2: Resilience Testing (Cache/Messaging Enabled)
```bash
# Upgrade to enable resilience features
helm upgrade reliability-demo ../app --set config.distributedCache.enabled=true --set config.messaging.enabled=true

# Run same load test to show improved performance
helm install k6-load-v2 . --set testType=load --wait
kubectl logs job/k6-load-v2

# Compare results - should show faster response times and fewer errors
```

## Configuration

The scripts use Helm template variables for dynamic configuration:
- `{{ .Values.target.service }}` - Target application service
- `{{ .Values.target.port }}` - Service port (default: 8080)
- Performance thresholds and scenarios are configurable via values.yaml

## Expected Results

- **Baseline**: Higher response times, timeout errors, connection failures
- **With Resilience**: Improved response times, reduced errors, better throughput