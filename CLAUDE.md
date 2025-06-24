# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a reliability demonstration application built with ASP.NET Core 8.0. It simulates various failure scenarios to test system resilience and provides a web interface for managing customer data with configurable failure injection. The application supports multiple data store backends (Redis, SQL Server) for demonstrating scalability and resilience patterns.

## Project Structure

```
src/ReliabilityDemo/
├── Controllers/
│   ├── ConfigController.cs      # Failure configuration management (/api/config)
│   ├── DataController.cs        # Customer CRUD operations (/api/customers)
│   └── HealthController.cs      # Health check endpoint (/api/health)
├── Models/
│   ├── Customer.cs              # Customer entity model with validation attributes
│   ├── CreateCustomerRequest.cs # Request model for creating customers
│   ├── UpdateCustomerRequest.cs # Request model for updating customers
│   ├── FailureConfig.cs         # Configuration model for failure rates
│   ├── DataStoreConfig.cs       # Data store provider configuration
│   ├── RedisDataStoreConfig.cs  # Redis-specific configuration
│   └── SqlServerDataStoreConfig.cs # SQL Server-specific configuration
├── Services/
│   ├── FailureSimulator.cs      # Core failure injection service
│   ├── IDataStore.cs            # Customer data store interface
│   ├── RedisDataStore.cs        # Redis-backed customer store with JSON serialization
│   └── SqlServerDataStore.cs    # SQL Server-backed customer store with EF Core
├── Data/
│   └── ReliabilityDemoContext.cs # Entity Framework DbContext for Customer entity
├── wwwroot/
│   ├── index.html              # Customer management web interface
│   └── technical.html          # Technical documentation page
├── Program.cs                  # Application entry point and DI configuration
├── ReliabilityDemo.csproj      # Project file with dependencies
├── Dockerfile                  # Container image definition
├── appsettings.json           # Production configuration
└── appsettings.Development.json # Development configuration
docker-compose.yml              # Multi-container deployment with Redis
helm-chart/                     # Helm chart for Kubernetes deployment
├── Chart.yaml                  # Chart metadata and dependencies
├── values.yaml                 # Configurable values
├── install.ps1                 # Helm install script (PowerShell)
├── uninstall.ps1               # Helm uninstall script (PowerShell)
└── templates/                  # Kubernetes resource templates
    ├── deployment.yaml         # Application deployment template
    ├── service.yaml            # Service template
    ├── configmap.yaml          # Configuration template
    ├── _helpers.tpl            # Template helpers
    └── NOTES.txt               # Post-install instructions
```

## Architecture

The application uses ASP.NET Core 8.0 with:

- **FailureSimulator**: Core service that introduces controlled failures (connection failures, timeouts, slow responses)
- **Customer Model**: Entity with Name, Email, Phone, Address, and timestamp fields
- **IDataStore Interface**: Customer-focused data storage abstraction with CRUD operations
- **RedisDataStore**: Redis-backed implementation using JSON serialization with auto-incrementing IDs  
- **SqlServerDataStore**: SQL Server-backed implementation using Entity Framework Core with Customer entity
- **API Controllers**: RESTful endpoints for customer operations (`/api/customers`), configuration, and health checks
- **Web Interface**: Customer management portal with create, read, update, delete operations and failure simulation

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
# Quick build and push (uses m1-01 tag)
./build-and-push.ps1

# Build and push with specific tag
./build-and-push.ps1 -Tag v1.0.0

# Manual build and push
docker build -t sixeyed/reliability-demo:m1-01 src/ReliabilityDemo/
docker push sixeyed/reliability-demo:m1-01
```


### Docker
```bash
# Build and run with Docker Compose (Redis + SQL Server + both app instances)
docker-compose up --build

# Run only Redis-backed instance
docker-compose up reliability-demo-redis redis

# Run only SQL Server-backed instance  
docker-compose up reliability-demo-sqlserver sqlserver

# Or build Docker image manually
docker build -t sixeyed/reliability-demo:m1-01 src/ReliabilityDemo/

# Push to Docker Hub
docker push sixeyed/reliability-demo:m1-01

# Run with Redis backend
docker run -p 8080:8080 -e DataStore__Provider=Redis -e ConnectionStrings__Redis=redis:6379 sixeyed/reliability-demo:m1-01

# Run with SQL Server backend
docker run -p 8081:8080 -e DataStore__Provider=SqlServer -e ConnectionStrings__SqlServer="Server=sqlserver;..." sixeyed/reliability-demo:m1-01
```

### Helm
```powershell
# Build and push Docker image first
docker build -t sixeyed/reliability-demo:m1-01 src/ReliabilityDemo/
docker push sixeyed/reliability-demo:m1-01

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

**Helm Configuration** (in `helm-chart/values.yaml`):
- `replicaCount`: Number of application replicas (default: 3)
- `config.dataStore.provider`: Backend provider ("Redis" or "SqlServer")
- `config.redisDataStore.maxConcurrentClients`: Redis concurrent clients (default: 10)
- `config.sqlServerDataStore.maxConcurrentClients`: SQL Server concurrent clients (default: 10)
- `config.failureConfig.*`: Failure simulation rates and timeouts
- `redis.enabled`: Enable Redis dependency (default: true)
- `sqlserver.enabled`: Enable SQL Server deployment (default: false)

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

### Application Architecture  
- All customer operations go through the `FailureSimulator` before hitting the data store
- ASP.NET Core dependency injection configures data store provider based on `DataStore:Provider` setting
- Connection strings configurable via `ConnectionStrings:Redis` and `ConnectionStrings:SqlServer`
- Static files served from web root with customer management interface
- Swagger/OpenAPI documentation available in development mode
- All failures are simulated - no actual network or database failures occur
- Multiple application instances can share Redis/SQL Server for horizontal scaling