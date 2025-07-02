# Terraform Testing Guide

This guide explains how to run the comprehensive test suite for the Terraform infrastructure.

## Quick Start

```powershell
# Run quick tests (format, validate, lint, unit tests)
./run-tests.ps1

# Run only unit tests
./run-tests.ps1 -TestType Unit

# Run full test suite including integration tests
./run-tests.ps1 -TestType All

# Run specific test
./run-tests.ps1 -TestType Unit -TestFilter TestAKSModuleDefaults
```

## Test Types

### 1. Quick Tests (Default)
Fast tests that don't create real resources:
- Terraform format check
- Terraform validation
- TFLint (if installed)
- Unit tests

```powershell
./run-tests.ps1 -TestType Quick
```

### 2. Unit Tests
Tests that validate Terraform plans without creating resources:
```powershell
./run-tests.ps1 -TestType Unit
```

### 3. Integration Tests
⚠️ **WARNING**: Creates real Azure resources and incurs costs!
```powershell
./run-tests.ps1 -TestType Integration
```

### 4. Security Tests
Runs security scanning tools:
```powershell
./run-tests.ps1 -TestType Security
```

### 5. All Tests
Runs the complete test suite:
```powershell
./run-tests.ps1 -TestType All
```

## Prerequisites

The script will check for required tools:
- ✅ Terraform (required)
- ✅ Go (required)
- ✅ Azure CLI (required)
- ⚠️ kubectl (optional)
- ⚠️ Trivy (optional, for security scanning)
- ⚠️ Checkov (optional, for security scanning)
- ⚠️ TFLint (optional, for linting)

Install missing tools:
```powershell
# macOS
brew install terraform go azure-cli kubectl trivy tflint
pip install checkov

# Windows with Chocolatey
choco install terraform golang azure-cli kubernetes-cli trivy
pip install checkov

# Windows with Scoop
scoop install terraform go azure-cli kubectl
pip install checkov
```

## Script Parameters

```powershell
./run-tests.ps1 `
    -TestType <All|Unit|Integration|Format|Validate|Security|Quick> `
    -TestFilter <string> `
    -Timeout <int> `
    -SkipPrereqCheck `
    -SkipCleanup `
    -GenerateCoverage `
    -Verbose
```

### Parameters:
- **TestType**: Type of tests to run (default: Quick)
- **TestFilter**: Run only tests matching this pattern
- **Timeout**: Test timeout in minutes (default: 30)
- **SkipPrereqCheck**: Skip prerequisite tool checks
- **SkipCleanup**: Don't clean up test resources after integration tests
- **GenerateCoverage**: Generate code coverage report
- **Verbose**: Show detailed test output

## Examples

### Run unit tests with coverage
```powershell
./run-tests.ps1 -TestType Unit -GenerateCoverage
```

### Run specific test with verbose output
```powershell
./run-tests.ps1 -TestType Unit -TestFilter TestAKSModule -Verbose
```

### Run integration tests without cleanup (for debugging)
```powershell
./run-tests.ps1 -TestType Integration -SkipCleanup
```

### Run all tests with custom timeout
```powershell
./run-tests.ps1 -TestType All -Timeout 120
```

## Test Output

The script provides colored output showing:
- ✓ PASS - Test passed
- ✗ FAIL - Test failed
- Test duration
- Summary statistics

Example output:
```
════════════════════════════════════════════════════════════
  Terraform Format Check
════════════════════════════════════════════════════════════

✓ PASS Format Check (2.34s)

════════════════════════════════════════════════════════════
  Unit Tests
════════════════════════════════════════════════════════════

Running unit tests...
✓ PASS Unit Tests (15.67s)
  Passed: 12, Failed: 0

════════════════════════════════════════════════════════════
  Test Summary
════════════════════════════════════════════════════════════

Total Tests: 4
Passed: 4
Duration: 00:25

Results:
✓ Format
✓ Validate
✓ Lint
✓ Unit Tests

ALL TESTS PASSED
```

## Troubleshooting

### Azure Authentication Issues
```powershell
# Login to Azure
az login

# Set subscription
az account set --subscription "Your Subscription Name"
```

### Go Module Issues
```powershell
# Clean module cache
go clean -modcache

# Re-download dependencies
go mod download
```

### Permission Issues
```powershell
# Make script executable (macOS/Linux)
chmod +x run-tests.ps1

# Run with PowerShell Core
pwsh ./run-tests.ps1
```

### Resource Cleanup
If tests fail and leave resources:
```powershell
# Manual cleanup of test resources
az group list --query "[?tags.ManagedBy=='Terratest'].name" -o tsv | `
    ForEach-Object { az group delete --name $_ --yes --no-wait }
```

## CI/CD Integration

The same tests run in GitHub Actions:
- **Pull Requests**: Quick tests only
- **Main Branch**: Full test suite
- **Nightly**: Integration tests
- **Manual**: On-demand testing

## Cost Management

Integration tests create minimal resources:
- Small VM sizes (Standard_B2s)
- Single node clusters
- Automatic cleanup after tests
- Resources tagged for identification

Estimated cost per test run: < $1 USD

## Writing New Tests

1. Add test file to appropriate directory:
   - `unit/` - For unit tests
   - `integration/` - For integration tests

2. Follow naming convention:
   - `module_name_test.go`
   - Test functions: `TestModuleNameFeature`

3. Use helper functions from `helpers/helpers.go`

4. Always clean up resources in integration tests

Example test:
```go
func TestNewFeature(t *testing.T) {
    t.Parallel()
    
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../../modules/mymodule",
        Vars: map[string]interface{}{
            "name": "test",
        },
    })
    
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)
}
```