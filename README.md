# SRE Resiliency Automation - Reliability Demo

A comprehensive reliability demonstration application built with ASP.NET Core 8.0 that showcases system resilience patterns and failure injection capabilities. This application simulates real-world failure scenarios to test system reliability and provides monitoring capabilities for observing behavior under stress.

## 🎯 Demo Flow

### Phase 1: Baseline (Issues Visible in Logs)
1. Deploy with basic configuration (no cache, no messaging)
2. Run load tests to generate traffic
3. Observe issues in application logs:
   - Connection timeouts
   - Slow response times
   - Resource contention
   - Database bottlenecks

### Phase 2: Resilience Patterns (Issues Resolved)
1. Enable distributed caching for improved read performance
2. Enable message-driven architecture for better write scalability
3. Run the same load tests
4. Compare logs to show improved performance and reliability

## 🏗️ Architecture

- **ASP.NET Core 8.0** web API with customer management
- **Redis** for caching and message queuing
- **SQL Server** for persistent data storage
- **Background Worker Service** for async message processing
- **Configurable Failure Injection** for testing resilience
- **Load Testing Suite** with K6 for performance validation
- **LGTM Stack** (Loki, Grafana, Tempo, Mimir) for observability

## 🚀 Quick Start

### Option 1: Helm Deployment (Recommended)
```powershell
# Build and push Docker images
./build-and-push.ps1

# Deploy to Kubernetes
cd helm/app
./install.ps1

# Check deployment status
kubectl get pods
helm status reliability-demo
```

### Option 2: Docker Compose
```bash
# Run complete stack locally
docker-compose up --build

# Access the application
open http://localhost:8080
```

## 📊 Key Features

### Failure Simulation
- **Connection Failures**: Simulates network connectivity issues
- **Timeouts**: Read/write timeout scenarios
- **Slow Responses**: Configurable response delays
- **Resource Limits**: Concurrent client limits on data stores

### Resilience Patterns
- **Distributed Caching**: Redis-backed cache with TTL and invalidation
- **Message-Driven Architecture**: Async processing with Redis pub/sub
- **Background Workers**: Separate containers for message processing
- **Graceful Degradation**: Cache failures don't break core functionality

### Observability
- **Health Checks**: `/api/health` endpoint for monitoring
- **Structured Logging**: Comprehensive application logging
- **Metrics Collection**: Performance and reliability metrics
- **Load Testing**: Integrated K6 test suites

## 🔧 Configuration

### Enabling Cache (Phase 2)
```yaml
config:
  distributedCache:
    enabled: true
    expirationSeconds: 300
```

### Enabling Messaging (Phase 2)
```yaml
config:
  messaging:
    enabled: true
    retryAttempts: 3
```

### Failure Injection Settings
```yaml
config:
  failureConfig:
    connectionFailureRate: 0.1    # 10% connection failures
    readTimeoutRate: 0.05         # 5% read timeouts
    writeTimeoutRate: 0.05        # 5% write timeouts
    slowResponseRate: 0.2         # 20% slow responses
```

## 📈 Load Testing

```bash
# Reset database between test runs
./reset-database.ps1

# Run K6 load tests
helm install k6-test helm/k6 --set testType=load
helm install k6-test helm/k6 --set testType=spike
helm install k6-test helm/k6 --set testType=soak

# Monitor test results
kubectl logs job/k6-test
```

## 🔍 Monitoring

```bash
# Deploy LGTM stack
helm install lgtm helm/lgtm

# Access Grafana dashboards
kubectl port-forward svc/lgtm-grafana 3000:3000
```

## 📚 Documentation

- [Technical Details](src/ReliabilityDemo/wwwroot/technical.html)
- [CLAUDE.md](CLAUDE.md) - Detailed project structure and implementation
- [API Documentation](http://localhost:8080/swagger) - Available in development mode

## 🎮 Demo Script

1. **Deploy baseline configuration** - Show application working but with performance issues
2. **Reset database** - `./reset-database.ps1` to start with clean data
3. **Run load tests** - Generate traffic to expose bottlenecks
4. **Review logs** - Point out timeout errors, slow responses, connection issues
5. **Enable cache and messaging** - Deploy resilience features
6. **Reset database again** - Clean slate for comparison
7. **Run same tests** - Demonstrate improved performance
8. **Compare results** - Show reduced errors and faster response times

## 🔧 Database Management

### Reset Database Between Tests
```powershell
# Reset with default settings
./reset-database.ps1

# With custom namespace/release
./reset-database.ps1 -Namespace demo -ReleaseName my-demo
```

The reset script uses `kubectl exec` to connect to the SQL Server pod and truncate the `Customers` table, providing a clean starting point for each demo run without requiring database restarts.

