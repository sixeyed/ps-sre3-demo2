# Terraform Testing

Complete Docker-based testing environment for Terraform infrastructure with Go, Azure CLI, and full toolchain.

## Quick Start

```bash
# Run unit tests
./test-docker.ps1 -TestType Unit

# Quick validation
./test-docker.ps1

# Interactive shell  
./test-docker.ps1 -Shell

# Clean up
./test-docker.ps1 -Clean
```

## Core Files

| File | Purpose |
|------|---------|
| **`Dockerfile`** | Debian-based image with Go 1.21, Terraform, Azure CLI, kubectl, Helm |
| **`docker-compose.yml`** | Services for tests, unit tests, and interactive shell |
| **`test-docker.ps1`** | Main PowerShell runner with all options |
| **`run-tests.sh`** | Bash script inside container that runs the actual tests |

## Test Types

| Type | Description | Duration |
|------|-------------|----------|
| **Quick** | Terraform format + validation (default) | 30 seconds |
| **Unit** | Real Go unit tests with Terratest | 2-5 minutes |
| **Validate** | Comprehensive Terraform validation | 1 minute |
| **Format** | Terraform format checking only | 10 seconds |
| **Security** | Basic validation (placeholder) | 30 seconds |

## Container Tools

The Docker image includes:
- ✅ **Go 1.21** - Full toolchain with Terratest framework
- ✅ **Terraform 1.5.7** - Infrastructure as Code
- ✅ **Azure CLI** - Azure integration 
- ✅ **kubectl & Helm** - Kubernetes tools
- ✅ **Debian base** - Reliable package ecosystem

## Usage Examples

### Basic Testing
```bash
# Default quick validation
./test-docker.ps1

# Specific test type
./test-docker.ps1 -TestType Unit
./test-docker.ps1 -TestType Validate
./test-docker.ps1 -TestType Format
```

### Development
```bash
# Interactive shell for debugging
./test-docker.ps1 -Shell

# Force rebuild (after changes)
./test-docker.ps1 -Build

# Verbose output
./test-docker.ps1 -Debug
```

### Cleanup
```bash
# Remove containers and images
./test-docker.ps1 -Clean

# Manual cleanup
docker compose down --rmi all
```

## Directory Structure

```
terraform/test/
├── Dockerfile              # Container definition
├── docker-compose.yml      # Service orchestration  
├── test-docker.ps1         # Main test runner
├── run-tests.sh            # Container test script
├── go.mod                  # Go dependencies
├── unit/                   # Unit test files
├── integration/            # Integration test files
├── fixtures/               # Test fixtures
└── helpers/                # Test helper functions
```

## Container Services

| Service | Purpose | Command |
|---------|---------|---------|
| **terraform-tests** | Main testing service | `docker compose run terraform-tests` |
| **terraform-unit** | Unit tests specifically | `docker compose run terraform-unit` | 
| **terraform-shell** | Interactive debugging | `docker compose run terraform-shell` |

## Manual Commands

```bash
# Build image
docker compose build terraform-tests

# Run quick tests
docker compose run --rm terraform-tests

# Run unit tests
docker compose run --rm terraform-unit

# Interactive shell
docker compose run --rm -it terraform-shell

# Clean up
docker compose down --rmi all
```

## Environment Variables

The container automatically uses these if available:
- `ARM_CLIENT_ID` - Azure service principal ID
- `ARM_CLIENT_SECRET` - Azure service principal secret  
- `ARM_SUBSCRIPTION_ID` - Azure subscription ID
- `ARM_TENANT_ID` - Azure tenant ID

## Volume Mounts

- `../:/workspace/terraform:ro` - Terraform code (read-only)
- `~/.azure:/root/.azure:ro` - Azure credentials (read-only)
- `~/.kube:/root/.kube:ro` - Kubernetes config (read-only)
- `./test-results:/workspace/test-results` - Test output

## Prerequisites

- Docker Desktop installed and running
- That's it! No other tools needed locally.

## Troubleshooting

### Build Issues
```bash
# Check Docker is running
docker version

# Clean rebuild
./test-docker.ps1 -Clean
./test-docker.ps1 -Build -Debug

# Check disk space
docker system df
```

### Test Failures
```bash
# Interactive debugging
./test-docker.ps1 -Shell

# Inside container
/run-tests.sh Unit
terraform validate
go test -v ./unit/...
```

### Performance
- First build: ~5-10 minutes (downloads base images)
- Subsequent builds: ~30 seconds (cached layers)
- Test execution: 30 seconds - 5 minutes depending on type

This setup provides a reliable, containerized testing environment that avoids local dependency installation while supporting the full spectrum of Terraform testing needs.