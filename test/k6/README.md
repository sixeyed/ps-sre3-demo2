# K6 Load Testing for Reliability Demo

This directory contains K6 load tests for the Customer Reliability Demo application.

## Test Scripts

### Customer Load Test (`customer-load-test.js`)
- **Purpose**: Test customer creation and retrieval under normal load
- **Load Pattern**: Gradual ramp up to 25 concurrent users over 4 minutes
- **Features**:
  - Creates customers via `/api/customers` POST endpoint
  - Validates successful creation (201 status)
  - Retrieves created customers to verify data integrity
  - Generates realistic customer data (names, emails, addresses)
  - Accommodates failure simulation with higher error thresholds

### Customer Spike Test (`customer-spike-test.js`)
- **Purpose**: Test system behavior under sudden load spikes
- **Load Pattern**: Quick spike from 5 to 50 users, then recovery
- **Features**:
  - Rapid load increase to test resilience
  - Focused on customer creation performance
  - Higher failure tolerance for spike conditions
  - Shorter sleep intervals for intensity

### Customer Soak Test (`customer-soak-test.js`)
- **Purpose**: Test system stability and performance over extended periods
- **Load Pattern**: Constant 10 concurrent users for 30 minutes
- **Features**:
  - Calls GET `/api/customers` to retrieve all customers
  - Tests read performance and consistency over time
  - Validates response format and data integrity
  - Simulates realistic user behavior with 5-15 second delays
  - Very low failure tolerance to catch degradation

## Usage

### Deploy Namespace and ConfigMap
```bash
kubectl apply -f 01-namespace.yaml
kubectl apply -f customer-test-configMap.yaml
```

### Run Load Test
```bash
kubectl apply -f customer-load-test-job.yaml
```

### Run Spike Test
```bash
kubectl apply -f customer-spike-test-job.yaml
```

### Run Soak Test (30 minutes)
```bash
kubectl apply -f customer-soak-test-job.yaml
```

### Monitor Test Progress
```bash
# Check job status
kubectl get jobs -n k6

# View test logs
kubectl logs job/k6-customer-load-test -n k6
kubectl logs job/k6-customer-spike-test -n k6
kubectl logs job/k6-customer-soak-test -n k6
```

### Clean Up
```bash
# Delete completed jobs
kubectl delete job k6-customer-load-test -n k6
kubectl delete job k6-customer-spike-test -n k6
kubectl delete job k6-customer-soak-test -n k6

# Delete ConfigMap
kubectl delete configmap k6-customer-test-scripts -n k6

# Optional: Delete entire namespace
kubectl delete namespace k6
```

## Test Thresholds

### Load Test
- HTTP request failure rate: < 15% (accommodates failure simulation)
- 95th percentile response time: < 3s (accommodates slow response simulation)
- Normal responses: < 1s

### Spike Test
- HTTP request failure rate: < 25% (higher tolerance for spike conditions)
- 95th percentile response time: < 5s

### Soak Test
- HTTP request failure rate: < 2% (very low tolerance for extended runs)
- 95th percentile response time: < 1s
- Normal responses: < 500ms

## Test Data Generation

Both tests generate realistic customer data:
- **Names**: Random first/last name combinations
- **Emails**: Unique email addresses with timestamps
- **Phones**: US phone number format
- **Addresses**: Realistic US address format

## Integration with Failure Simulation

The tests are designed to work with the application's failure simulation features:
- Higher error rate thresholds account for simulated connection failures
- Extended timeout thresholds accommodate simulated slow responses
- Validation checks handle both successful and failed scenarios appropriately

## Monitoring

Tests include comprehensive checks for:
- HTTP status codes
- Response times
- Data integrity validation
- System recovery after failures