# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a reliability demonstration application built with ASP.NET Core 8.0. It simulates various failure scenarios to test system resilience and provides a web interface for managing customer data with configurable failure injection. The application supports multiple data store backends (Redis, SQL Server) for demonstrating scalability and resilience patterns.

## Project Structure

```
src/
├── ReliabilityDemo/                # Main API application
│   ├── Controllers/
│   │   ├── ConfigController.cs      # Failure configuration management (/api/config)
│   │   ├── DataController.cs        # Customer CRUD operations (/api/customers)
│   │   └── HealthController.cs      # Health check endpoint (/api/health)
│   ├── Models/
│   │   ├── FailureConfig.cs         # Configuration model for failure rates
│   │   ├── CreateCustomerRequest.cs # Request model for creating customers
│   │   ├── UpdateCustomerRequest.cs # Request model for updating customers
│   │   └── DistributedCacheConfig.cs # Distributed cache configuration
│   ├── Services/
│   │   ├── FailureSimulator.cs      # Core failure injection service
│   │   ├── IDistributedCache.cs     # Distributed cache interface
│   │   ├── RedisDistributedCache.cs # Redis-backed cache implementation
│   │   ├── IMessagePublisher.cs     # Message publishing interface
│   │   └── RedisMessagePublisher.cs # Redis pub/sub message publisher
│   ├── wwwroot/
│   │   ├── index.html              # Customer management web interface
│   │   └── technical.html          # Technical documentation page
│   ├── Program.cs                  # Application entry point and DI configuration
│   ├── ReliabilityDemo.csproj      # Project file with dependencies
│   ├── Dockerfile                  # Container image definition
│   ├── appsettings.json           # Production configuration
│   └── appsettings.Development.json # Development configuration
├── ReliabilityDemo.DataStore/      # Shared data store assembly
│   ├── Models/
│   │   ├── Customer.cs              # Customer entity model with validation attributes
│   │   ├── DataStoreConfig.cs       # Data store provider configuration
│   │   ├── RedisDataStoreConfig.cs  # Redis-specific configuration
│   │   └── SqlServerDataStoreConfig.cs # SQL Server-specific configuration
│   ├── Services/
│   │   ├── IDataStore.cs            # Customer data store interface
│   │   ├── RedisDataStore.cs        # Redis-backed customer store with JSON serialization
│   │   └── SqlServerDataStore.cs    # SQL Server-backed customer store with EF Core
│   ├── Data/
│   │   └── ReliabilityDemoContext.cs # Entity Framework DbContext for Customer entity
│   └── ReliabilityDemo.DataStore.csproj # Shared data store project file
├── ReliabilityDemo.Messaging/      # Shared messaging assembly
│   ├── CustomerMessage.cs          # Customer operation message model
│   ├── MessagingConfig.cs          # Messaging configuration model
│   └── ReliabilityDemo.Messaging.csproj # Shared messaging project file
└── ReliabilityDemo.Worker/         # Background message processing worker
    ├── CustomerMessageWorker.cs    # Background service for processing customer messages
    ├── Program.cs                  # Worker entry point and DI configuration
    ├── ReliabilityDemo.Worker.csproj # Worker project file
    └── Dockerfile                  # Worker container image definition
docker-compose.yml              # Multi-container deployment with Redis
helm/                           # Helm charts for Kubernetes deployment
├── app/                        # Application Helm chart
│   ├── Chart.yaml              # Chart metadata and dependencies
│   ├── values.yaml             # Configurable values
│   ├── install.ps1             # Helm install script (PowerShell)
│   ├── uninstall.ps1           # Helm uninstall script (PowerShell)
│   └── templates/              # Kubernetes resource templates
├── lgtm/                       # LGTM monitoring stack chart
└── k6/                         # K6 load testing chart
    ├── scripts/                # K6 JavaScript test files
    │   ├── customer-load-test.js    # Load testing script
    │   ├── customer-spike-test.js   # Spike testing script
    │   └── customer-soak-test.js    # Soak testing script
    └── templates/              # K6 job templates
```

## Architecture

The application uses ASP.NET Core 8.0 with:

- **FailureSimulator**: Core service that introduces controlled failures (connection failures, timeouts, slow responses)
- **Customer Model**: Entity with Name, Email, Phone, Address, and timestamp fields
- **IDataStore Interface**: Customer-focused data storage abstraction with CRUD operations
- **RedisDataStore**: Redis-backed implementation using JSON serialization with auto-incrementing IDs  
- **SqlServerDataStore**: SQL Server-backed implementation using Entity Framework Core with Customer entity
- **IDistributedCache Interface**: Caching abstraction with get/set/invalidate operations for customers
- **RedisDistributedCache**: Redis-backed cache implementation with configurable TTL for performance optimization
- **Message-Driven Writes**: Async processing pattern using Redis pub/sub for all write operations
- **IMessagePublisher Interface**: Message publishing abstraction for async operations
- **CustomerMessageWorker**: Separate containerized service that processes customer operation messages from Redis
- **API Controllers**: RESTful endpoints for customer operations (`/api/customers`), configuration, and health checks
- **Web Interface**: Customer management portal with create, read, update, delete operations and failure simulation
- **OpenTelemetry Integration**: Prometheus metrics endpoint (`/metrics`) for KEDA autoscaling triggers
- **KEDA ScaledObjects**: Event-driven autoscaling based on HTTP request metrics and Redis queue depth

## Common Commands

### Development
```bash
# Run the application
dotnet run --project src/ReliabilityDemo/ReliabilityDemo.csproj

# Build the application
dotnet build src/ReliabilityDemo/ReliabilityDemo.csproj

# Restore dependencies
dotnet restore src/ReliabilityDemo/ReliabilityDemo.csproj
```

### Docker Image
```powershell
# Quick build and push (uses m3 tag)
./build-and-push.ps1

# Build and push with specific tag
./build-and-push.ps1 -Tag v1.0.0

# Manual build and push
docker build -t sixeyed/reliability-demo:m3 src/ReliabilityDemo/
docker push sixeyed/reliability-demo:m3
```


### Docker
```bash
# Build and run complete stack (API + Worker + Redis + SQL Server)
docker-compose up --build

# Build individual containers
docker build -t sixeyed/reliability-demo:m3 src/ReliabilityDemo/
docker build -t sixeyed/reliability-demo-worker:m3 src/ReliabilityDemo.Worker/

# Push to Docker Hub
docker push sixeyed/reliability-demo:m3
docker push sixeyed/reliability-demo-worker:m3

# Run API only (requires Redis for messaging)
docker run -p 8080:8080 -e DataStore__Provider=Redis -e ConnectionStrings__Redis=redis:6379 sixeyed/reliability-demo:m3

# Run Worker only (requires Redis + SQL Server)
docker run -e ConnectionStrings__Redis=redis:6379 -e ConnectionStrings__SqlServer="Server=sqlserver;..." sixeyed/reliability-demo-worker:m3
```

### Helm
```powershell
# Build and push Docker image first
docker build -t sixeyed/reliability-demo:m3 src/ReliabilityDemo/
docker push sixeyed/reliability-demo:m3

# Deploy with Redis backend (default)
cd helm-chart
./install.ps1

# Deploy with SQL Server backend
./install.ps1 -ReleaseName demo-sql -Namespace sqlserver
helm upgrade demo-sql . --set config.dataStore.provider=SqlServer --set sqlserver.enabled=true --set redis.enabled=false

# Scale the application
helm upgrade reliability-demo . --set replicaCount=10

# Check status
helm status reliability-demo
kubectl get pods

# Uninstall
./uninstall.ps1
```


## API Endpoints

### Customer Management (`/api/customers`)
- `GET /api/customers` - Get all customers
- `GET /api/customers/{id}` - Get customer by ID  
- `POST /api/customers` - Create new customer
- `PUT /api/customers/{id}` - Update existing customer
- `DELETE /api/customers/{id}` - Delete customer

**Customer Model**:
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com", 
  "phone": "+1-555-0123",
  "address": "123 Main St, Anytown, USA",
  "createdAt": "2024-01-01T10:00:00Z",
  "updatedAt": "2024-01-01T12:00:00Z"
}
```

### Other Endpoints
- `GET /api/config` - Get current failure configuration
- `POST /api/config` - Update failure configuration  
- `POST /api/config/reset` - Reset failure configuration to defaults
- `GET /api/health` - Health check endpoint

## Key Features

### Failure Simulation
The application can inject various failure conditions:

**FailureSimulator**:
- Connection failures (503 Service Unavailable)
- Read/write timeouts (408 Request Timeout)
- Slow responses (configurable delay)

**Data Store Backends**:
- Redis: Concurrent client limit (503 Service Unavailable when limit exceeded)
- SQL Server: Concurrent client limit with Entity Framework Core and automatic schema migration

### Configuration
Failure rates are configurable via the `/api/config` endpoint:
- `ConnectionFailureRate`: Probability of connection failures (0.0-1.0)
- `ReadTimeoutRate`: Probability of read timeouts (0.0-1.0)
- `WriteTimeoutRate`: Probability of write timeouts (0.0-1.0)
- `SlowResponseRate`: Probability of slow responses (0.0-1.0)

**Data Store Configuration** (in `appsettings.json`):
- `DataStore:Provider`: Backend provider ("Redis" or "SqlServer")
- `RedisDataStore:MaxConcurrentClients`: Redis concurrent client limit (default: 5)
- `SqlServerDataStore:MaxConcurrentClients`: SQL Server concurrent client limit (default: 5)
- `SqlServerDataStore:AutoMigrate`: Auto-create database schema (default: true)

**Distributed Cache Configuration** (in `appsettings.json`):
- `DistributedCache:Enabled`: Enable distributed caching (default: false in production, true in development)
- `DistributedCache:ExpirationSeconds`: Cache TTL in seconds (default: 300 production, 60 development)

**Messaging Configuration** (in `appsettings.json`):
- `Messaging:Enabled`: Enable async message processing (default: true)
- `Messaging:CustomerChannelName`: Redis pub/sub channel name (default: "customer_operations")
- `Messaging:RetryAttempts`: Number of retry attempts for failed message processing (default: 3)
- `Messaging:RetryDelayMs`: Base delay between retries in milliseconds (default: 1000 production, 500 development)

**Helm Configuration** (in `helm-chart/values.yaml`):
- `replicaCount`: Number of application replicas (default: 6)
- `config.dataStore.provider`: Backend provider ("Redis" or "SqlServer")
- `config.redisDataStore.maxConcurrentClients`: Redis concurrent clients (default: 2)
- `config.sqlServerDataStore.maxConcurrentClients`: SQL Server concurrent clients (default: 2)
- `config.distributedCache.enabled`: Enable distributed caching (default: true)
- `config.distributedCache.expirationSeconds`: Cache TTL in seconds (default: 300)
- `config.failureConfig.*`: Failure simulation rates and timeouts
- `redis.enabled`: Enable Redis dependency (default: true)
- `sqlserver.enabled`: Enable SQL Server deployment (default: true)

### Customer Management Interface
The web interface (`index.html`) provides:
- **Customer Creation**: Form-based customer creation with validation
- **Customer Lookup**: Search customers by ID with detailed display
- **Customer Database**: Tabular view of all customers with delete actions
- **Failure Configuration**: Real-time failure rate configuration with sliders
- **Demo Controls**: Toggle panel for adjusting failure simulation parameters

## Important Implementation Details

### Data Storage
- **Redis Backend**: Customers stored as JSON with key pattern `customer:{id}`, auto-incrementing ID counter at `customer:id:counter`
- **SQL Server Backend**: Customer entity with EF Core, auto-incrementing primary key, unique email constraint
- **Interface Design**: Both backends implement the same `IDataStore` interface for customer CRUD operations
- **Thread Safety**: Concurrent client tracking with locks in both Redis and SQL Server implementations

### Distributed Caching
- **Cache Layer**: Sits between DataController and data stores for read performance optimization
- **Redis-Backed**: Uses separate Redis connection for caching regardless of data store provider
- **Cache Keys**: Individual customers (`cache:customer:{id}`) and all customers (`cache:all_customers`)
- **TTL Support**: Configurable expiration time for automatic cache invalidation
- **Cache-Aside Pattern**: Cache miss triggers data store fetch, then caches result for subsequent reads
- **Invalidation Strategy**: Creates/updates/deletes invalidate both individual and collection caches
- **Graceful Degradation**: Cache failures don't break application functionality

### Message-Driven Architecture
- **Separate Containers**: API and Worker run in separate containers for independent scaling
- **Async Write Operations**: All customer write operations (Create/Update/Delete) use Redis pub/sub messaging
- **API Response Pattern**: Write endpoints return HTTP 202 Accepted with message tracking information
- **Background Processing**: CustomerMessageWorker service processes messages asynchronously in dedicated container
- **Retry Logic**: Failed messages retry with exponential backoff (configurable attempts and delays)
- **Message Channel**: Uses Redis pub/sub channel `customer_operations` for all customer messages
- **Correlation Tracking**: Each message includes correlation ID for request tracing
- **Data Consistency**: Cache invalidation happens immediately on write request, actual persistence via background worker
- **Reliability**: Worker container continues processing even if API instances restart
- **Independent Scaling**: API and Worker containers can scale independently based on load patterns

### KEDA Event-Driven Autoscaling (Demo 2)
- **Web ScaledObject**: Scales based on HTTP request metrics from Prometheus (helm/app/templates/web-scaledobject.yaml)
- **Worker ScaledObject**: Scales based on Redis queue depth (helm/app/templates/worker-scaledobject.yaml)  
- **Metrics Source**: OpenTelemetry exports ASP.NET Core metrics to Prometheus endpoint
- **Scaling Triggers**: HTTP requests per second (threshold: 50) and Redis list length (threshold: 3)
- **Scaling Range**: Web 2-10 replicas, Worker 1-5 replicas
- **Prometheus Integration**: KEDA queries Prometheus at `prometheus-server.monitoring.svc.cluster.local:80`

### Application Architecture  
- All customer operations go through the `FailureSimulator` before hitting the data store
- ASP.NET Core dependency injection configures data store provider based on `DataStore:Provider` setting
- Connection strings configurable via `ConnectionStrings:Redis` and `ConnectionStrings:SqlServer`
- Static files served from web root with customer management interface
- Swagger/OpenAPI documentation available in development mode
- All failures are simulated - no actual network or database failures occur
- Multiple application instances can share Redis/SQL Server for horizontal scaling

## M3 Demo Infrastructure Profiles

The project supports multiple infrastructure profiles for demonstrating different scaling patterns:

### M3 Demo 1 - Static Over-Provisioned Infrastructure
- **Profile**: `m3demo1` (terraform/profiles/m3demo1.tfvars)
- **Purpose**: Demonstrate wasteful static infrastructure that fails under spike load
- **VM Size**: Standard_D8s_v5 (8 vCPUs, 32 GB RAM) - intentionally oversized
- **Scaling**: Fixed 3 nodes, no autoscaling
- **Resource Allocation**: High CPU/memory limits (2 CPU, 2Gi RAM) with high replica counts (6 replicas)
- **Expected Behavior**: Load and soak tests pass, spike test (600 users) fails due to connection limits

### M3 Demo 2 - Dynamic Right-Sized Infrastructure  
- **Profile**: `m3demo2` (terraform/profiles/m3demo2.tfvars)
- **Purpose**: Demonstrate efficient dynamic scaling with KEDA
- **VM Size**: Standard_D4s_v5 (4 vCPUs, 16 GB RAM) - right-sized for efficiency
- **Scaling**: 2-7 nodes with cluster autoscaler and KEDA enabled
- **Resource Allocation**: Efficient resources (0.5 CPU request, 1.5 CPU limit, 1Gi RAM) with minimal replicas (2 web, 1 worker)
- **KEDA Autoscaling**: HTTP request-based scaling using Prometheus metrics, Redis queue-based worker scaling
- **OpenTelemetry Metrics**: Prometheus metrics endpoint for KEDA triggers (src/ReliabilityDemo/Program.cs)
- **Expected Behavior**: All tests pass (224,670 total iterations), 85% cost savings vs Demo 1

### Key Differences
- **Infrastructure Cost**: Demo 1 uses ~3x more compute resources
- **Resource Groups**: Demo 1 uses `reliability-demo-production-m3demo1`, Demo 2 uses `reliability-demo-production-m3demo2`
- **Scaling Strategy**: Demo 1 static vs Demo 2 dynamic
- **Failure Behavior**: Demo 1 fails at connection limits (600 users), Demo 2 scales to handle load
- **Technology Stack**: Demo 2 adds KEDA, Prometheus, OpenTelemetry metrics

## Git Repository Configuration

**IMPORTANT**: This repository has two git remotes configured:

- **origin**: Internal git server (git.sixeyed)
- **github**: Public GitHub repository (github.com/sixeyed/ps-sre3-demo2)

### Git Remote Management
```bash
# Check current remotes
git remote -v

# Always push to GitHub for workflow triggers
git push github main

# Do NOT push to origin for GitHub Actions
# GitHub workflows only trigger from the github remote
```

### GitHub Actions Deployment
```bash
# Deploy with specific profile (after pushing to github remote)
gh workflow run deploy-infrastructure.yml -f environment=production -f action=apply -f profile=m3demo2 -R sixeyed/ps-sre3-demo2

# CRITICAL: Always push changes to 'github' remote before triggering workflows
# GitHub Actions will not see changes pushed only to 'origin'
```

## M3 Demo Workflow

### Demo 1 Setup
```powershell
# From m3/demo1 directory
./setup.ps1
```

### Demo 2 Setup  
```powershell
# From m3/demo2 directory
./setup.ps1
```

### K6 Load Testing
```powershell
# Run all tests (soak 10min, load 5min, spike 5min)
./run-k6-tests.ps1

# Run Demo 1 tests on Demo 2 infrastructure (proves KEDA fixes issues)
./run-k6-tests-demo1.ps1

# Expected results:
# Demo 1: Soak ✓, Load ✓, Spike ✗ (connection failures at 600 users)  
# Demo 2: Soak ✓, Load ✓, Spike ✓ (224,670 iterations, KEDA scales to handle load)
```