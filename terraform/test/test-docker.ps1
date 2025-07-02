#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Terraform tests using Docker with full toolchain

.DESCRIPTION
    Uses Docker Compose to build and run Terraform tests with Go, Azure CLI,
    kubectl, Helm, and Terratest for comprehensive testing

.PARAMETER TestType
    Type of tests to run (Quick, Unit, Validate, Format, Security)

.PARAMETER Build
    Force rebuild of Docker image

.PARAMETER Shell
    Start interactive shell

.PARAMETER Clean
    Clean up Docker resources

.PARAMETER ShowDetails
    Show verbose output

.EXAMPLE
    ./test-docker.ps1 -TestType Unit
    ./test-docker.ps1 -TestType Quick
    ./test-docker.ps1 -Shell
    ./test-docker.ps1 -Clean
    ./test-docker.ps1 -ShowDetails
#>

[CmdletBinding()]
param(
    [ValidateSet('All', 'Unit', 'Integration', 'Format', 'Validate', 'Security', 'Quick')]
    [string]$TestType = 'Quick',
    
    [switch]$Build,
    [switch]$Shell,
    [switch]$Clean,
    [switch]$ShowDetails,
    
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Write-Status {
    param([string]$Message)
    Write-Host "🔧 $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Get-ComposeCommand {
    # Try new docker compose first
    try {
        $null = docker compose version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return "docker compose"
        }
    }
    catch {}
    
    # Try legacy docker-compose
    try {
        $null = docker-compose version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return "docker-compose"
        }
    }
    catch {}
    
    throw "Docker Compose not found"
}

function Test-Prerequisites {
    # Check Docker
    try {
        $null = docker version 2>&1
        if ($LASTEXITCODE -ne 0) { throw }
        Write-Success "Docker is available"
    }
    catch {
        Write-Error "Docker is not running"
        return $false
    }
    
    # Check Docker Compose
    try {
        $script:ComposeCmd = Get-ComposeCommand
        Write-Success "Docker Compose is available"
        return $true
    }
    catch {
        Write-Error "Docker Compose not found"
        return $false
    }
}

function Build-TestImage {
    Write-Status "Building Terraform test image..."
    Write-Host "This may take 5-10 minutes on first build..." -ForegroundColor Yellow
    
    try {
        $buildArgs = @('build', 'terraform-tests')
        
        if ($ShowDetails) {
            $buildArgs += '--progress', 'plain'
            $buildArgs += '--no-cache'
        }
        
        $buildCmd = "$script:ComposeCmd $($buildArgs -join ' ')"
        Write-Status "Running: $buildCmd"
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-Expression $buildCmd
        $sw.Stop()
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Build completed in $($sw.Elapsed.ToString('mm\:ss'))"
            return $true
        } else {
            Write-Error "Build failed with exit code $LASTEXITCODE"
            return $false
        }
    }
    catch {
        Write-Error "Build exception: $_"
        return $false
    }
}

function Run-Tests {
    param([string]$TestType)
    
    Write-Status "Running $TestType tests..."
    
    # Choose the right service
    $service = if ($TestType -eq "Unit") { "terraform-unit" } else { "terraform-tests" }
    
    try {
        $runArgs = @('run', '--rm', $service)
        
        # Override command for non-default test types
        if ($TestType -ne "Quick" -and $service -eq "terraform-tests") {
            $runArgs += $TestType
        }
        
        $runCmd = "$script:ComposeCmd $($runArgs -join ' ')"
        
        if ($ShowDetails) {
            Write-Status "Running: $runCmd"
        }
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-Expression $runCmd
        $sw.Stop()
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Tests completed successfully in $($sw.Elapsed.ToString('mm\:ss'))"
            return $true
        } else {
            Write-Error "Tests failed with exit code $LASTEXITCODE"
            return $false
        }
    }
    catch {
        Write-Error "Test execution failed: $_"
        return $false
    }
}

function Start-InteractiveShell {
    Write-Status "Starting interactive shell..."
    
    try {
        $shellCmd = "$script:ComposeCmd run --rm -it terraform-shell"
        
        Write-Host @"
🚀 Starting interactive shell with full toolchain...

Available tools:
  - Go 1.21 with Terratest framework
  - Terraform 1.5.7  
  - Azure CLI
  - kubectl & Helm
  - All your Terraform code

Your files are at: /workspace/terraform
Test files are at: /workspace/terraform/test

Example commands:
  /run-tests.sh Unit        # Run unit tests
  /run-tests.sh Validate    # Validate Terraform
  go test -v ./unit/...     # Direct Go testing
  terraform validate        # Direct validation
"@ -ForegroundColor Green
        
        Invoke-Expression $shellCmd
    }
    catch {
        Write-Error "Shell failed: $_"
    }
}

function Test-ImageExists {
    try {
        $images = docker images terraform-tests -q 2>&1
        return ($LASTEXITCODE -eq 0 -and $images -and $images.Trim() -ne "")
    }
    catch {
        return $false
    }
}

function Clean-Resources {
    Write-Status "Cleaning up Docker resources..."
    
    try {
        Invoke-Expression "$script:ComposeCmd down --rmi all --volumes"
        docker system prune -f
        
        # Clean up test results
        if (Test-Path "./test-results") {
            Remove-Item -Recurse -Force "./test-results"
        }
        
        Write-Success "Cleanup completed"
    }
    catch {
        Write-Error "Cleanup failed: $_"
    }
}

function Show-TestTypes {
    Write-Host @"
🧪 Available Test Types:

Quick     - Fast Terraform validation (default)
Validate  - Comprehensive Terraform validation  
Format    - Terraform format checking
Unit      - Go unit tests with Terratest framework
Security  - Basic validation (security tools not included)

The Docker image includes:
✅ Go 1.21 with full toolchain
✅ Terraform 1.5.7
✅ Azure CLI
✅ kubectl & Helm  
✅ Terratest framework for unit testing

Examples:
  ./test-docker.ps1                     # Quick validation
  ./test-docker.ps1 -TestType Unit      # Unit tests
  ./test-docker.ps1 -TestType Validate  # Full validation
  ./test-docker.ps1 -Shell              # Interactive shell
  ./test-docker.ps1 -Clean              # Cleanup
"@ -ForegroundColor Cyan
}

# Main execution
function Main {
    Write-Host @"
╔══════════════════════════════════════════════════════════╗
║              Terraform Docker Test Runner               ║
║                                                          ║
║  Full toolchain with Go, Terraform, Azure CLI & more    ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta
    
    # Check we're in the right directory
    if (-not (Test-Path "docker-compose.yml")) {
        Write-Error "docker-compose.yml not found"
        Write-Host "Please run this from the terraform/test directory"
        exit 1
    }
    
    # Show help if requested
    if ($Help) {
        Show-TestTypes
        return
    }
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Handle special operations
    if ($Clean) {
        Clean-Resources
        return
    }
    
    # Build if needed or requested
    if ($Build -or -not (Test-ImageExists)) {
        if (-not (Build-TestImage)) {
            Write-Error "Failed to build Docker image"
            Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
            Write-Host "  1. Check Docker Desktop is running"
            Write-Host "  2. Try: ./test-docker.ps1 -ShowDetails"
            Write-Host "  3. Check available disk space"
            exit 1
        }
    } else {
        Write-Success "Using existing Docker image"
    }
    
    # Create test results directory
    if (-not (Test-Path "./test-results")) {
        New-Item -ItemType Directory -Path "./test-results" | Out-Null
    }
    
    # Run tests or shell
    if ($Shell) {
        Start-InteractiveShell
    } else {
        $success = Run-Tests -TestType $TestType
        
        if ($success) {
            Write-Host "`n🎉 $TestType tests completed successfully!" -ForegroundColor Green
            
            if ($TestType -eq "Unit") {
                Write-Host "✨ Full unit tests with Terratest framework!" -ForegroundColor Green
            }
            
            Write-Host "`nTest results available in: ./test-results/" -ForegroundColor Cyan
        } else {
            Write-Host "`n💥 $TestType tests failed!" -ForegroundColor Red
            Write-Host "`nNext steps:" -ForegroundColor Yellow
            Write-Host "  1. Check the error output above"
            Write-Host "  2. Try: ./test-docker.ps1 -Shell for debugging"
            Write-Host "  3. Fix any issues in your .tf files"
            exit 1
        }
    }
}

# Initialize
$script:ComposeCmd = ""

Main