# Docker-based Terraform Testing

No need to install prerequisites locally! Run all Terraform tests in a containerized environment.

## Quick Start

```bash
# Run quick tests (format, validate, unit tests)
./test-docker.ps1

# Run unit tests only
./test-docker.ps1 -TestType Unit

# Start interactive shell for debugging
./test-docker.ps1 -Shell
```

## Prerequisites

Only Docker is required:
- ✅ Docker Desktop (Windows/Mac) or Docker Engine (Linux)
- ✅ Azure CLI login (for integration tests only)

That's it! No need to install:
- ❌ Terraform
- ❌ Go
- ❌ kubectl
- ❌ Helm
- ❌ TFLint
- ❌ Trivy
- ❌ Checkov
- ❌ PowerShell Core

## Container Includes

The Docker image contains all testing tools:
- **Terraform** 1.5.7
- **Go** 1.21 
- **Azure CLI** (latest)
- **kubectl** (latest)
- **Helm** 3.13.1
- **TFLint** (latest)
- **Trivy** (latest)
- **Checkov** (latest)
- **PowerShell Core** 7.4.0
- **Infracost** (latest)

## Usage Examples

### Basic Testing
```bash
# Quick validation tests
./test-docker.ps1

# Unit tests only (fast)
./test-docker.ps1 -TestType Unit

# All tests including integration (creates Azure resources)
./test-docker.ps1 -TestType All

# Security scanning
./test-docker.ps1 -TestType Security
```

### Advanced Options
```bash
# Run specific test pattern
./test-docker.ps1 -TestType Unit -TestFilter TestAKSModule

# Generate coverage report
./test-docker.ps1 -TestType Unit -GenerateCoverage

# Force rebuild Docker image
./test-docker.ps1 -Build

# Integration tests without cleanup (for debugging)
./test-docker.ps1 -TestType Integration -SkipCleanup
```

### Interactive Mode
```bash
# Start shell in container
./test-docker.ps1 -Shell

# Inside the container:
pwsh ./run-tests.ps1 -TestType Unit
terraform version
go test -v ./unit/...
```

### Docker Compose Alternative
```bash
# Run tests with docker-compose
docker-compose run terraform-tests -TestType Unit

# Interactive shell
docker-compose run terraform-shell
```

## Azure Authentication

### Option 1: Azure CLI Login (Recommended)
```bash
# Login locally (credentials mounted to container)
az login
./test-docker.ps1 -TestType Integration
```

### Option 2: Service Principal
```bash
# Set environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

./test-docker.ps1 -TestType Integration
```

### Option 3: Managed Identity
```bash
# For Azure VMs/Container Instances
export ARM_USE_MSI=true
./test-docker.ps1 -TestType Integration
```

## Test Types

| Type | Description | Duration | Azure Resources |
|------|-------------|----------|-----------------|
| `Quick` | Format, validate, lint, unit tests | 2-5 min | None |
| `Unit` | Terraform plan validation | 1-3 min | None |
| `Integration` | Full deployment tests | 10-20 min | ✅ Creates resources |
| `Security` | Trivy + Checkov scans | 1-2 min | None |
| `All` | Complete test suite | 15-30 min | ✅ Creates resources |

## Directory Structure

```
terraform/test/
├── Dockerfile              # Test environment image
├── docker-compose.yml      # Compose configuration
├── test-docker.ps1         # Docker test runner script
├── run-tests.ps1           # Test script (runs in container)
├── test-results/           # Test outputs (mounted volume)
├── unit/                   # Unit test files
├── integration/            # Integration test files
└── helpers/                # Test helper functions
```

## Volumes and Mounts

The container mounts:
- `../:/workspace:ro` - Terraform code (read-only)
- `~/.azure:/root/.azure:ro` - Azure credentials (read-only)  
- `~/.kube:/root/.kube:ro` - Kubernetes config (read-only)
- `./test-results:/workspace/test-results` - Test outputs

## Troubleshooting

### Docker Issues
```bash
# Check Docker is running
docker version

# Pull latest Go image manually
docker pull golang:1.21-alpine

# Clean up everything
./test-docker.ps1 -Clean
```

### Authentication Issues
```bash
# Check Azure login
az account show

# Login if needed
az login

# Set subscription
az account set --subscription "your-subscription"
```

### Build Issues
```bash
# Force rebuild
./test-docker.ps1 -Build

# Check build logs
docker build -t terraform-tests -f Dockerfile .
```

### Test Failures
```bash
# Run in interactive mode
./test-docker.ps1 -Shell

# Inside container, run specific test
go test -v -run TestSpecificTest ./unit/...

# Check Terraform directly
terraform plan -var-file=../terraform.tfvars.example
```

## Performance Tips

1. **Layer Caching**: The Dockerfile is optimized for layer caching
2. **Parallel Tests**: Unit tests run in parallel for speed
3. **Minimal Resources**: Integration tests use smallest possible VM sizes
4. **Fast Base Image**: Uses Alpine Linux for smaller image size

## Cost Management

Integration tests create minimal Azure resources:
- Small VM sizes (Standard_B2s)
- Single node clusters  
- Automatic cleanup after tests
- Resources tagged with `TestID` for tracking

Estimated cost per integration test run: < $1 USD

## CI/CD Integration

Use the same Docker image in CI/CD:

```yaml
# GitHub Actions example
- name: Run Terraform Tests
  run: |
    cd terraform/test
    ./test-docker.ps1 -TestType Unit
```

```yaml
# Azure DevOps example
- script: |
    cd terraform/test  
    pwsh ./test-docker.ps1 -TestType Unit
  displayName: 'Run Terraform Tests'
```

## Cleanup

```bash
# Clean up Docker resources
./test-docker.ps1 -Clean

# Manual cleanup
docker rmi terraform-tests
docker system prune -f
```

This containerized approach ensures consistent testing environments across different machines and CI/CD systems!