#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Debug Docker build issues for Terraform testing

.DESCRIPTION
    Helps diagnose and fix Docker build problems step by step

.EXAMPLE
    ./debug-docker.ps1
#>

$ErrorActionPreference = 'Continue'

function Write-Step {
    param([string]$Message)
    Write-Host "`n🔍 $Message" -ForegroundColor Yellow
}

function Write-Check {
    param([string]$Message, [bool]$Success)
    $icon = if ($Success) { "✅" } else { "❌" }
    $color = if ($Success) { "Green" } else { "Red" }
    Write-Host "$icon $Message" -ForegroundColor $color
}

function Test-DockerBasics {
    Write-Step "Checking Docker basics..."
    
    # Test Docker command
    try {
        $dockerVersion = docker version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Check "Docker is installed and running" $true
            $version = ($dockerVersion | Select-String "Version:" | Select-Object -First 1).ToString().Trim()
            Write-Host "   $version"
        } else {
            Write-Check "Docker is not working properly" $false
            Write-Host $dockerVersion
            return $false
        }
    }
    catch {
        Write-Check "Docker command failed: $_" $false
        return $false
    }
    
    # Test basic image pull
    Write-Host "`n   Testing basic image pull..."
    try {
        $pullOutput = docker pull hello-world 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Check "Can pull Docker images" $true
        } else {
            Write-Check "Cannot pull Docker images" $false
            Write-Host $pullOutput
        }
    }
    catch {
        Write-Check "Image pull failed: $_" $false
    }
    
    return $true
}

function Test-SimpleBuild {
    Write-Step "Testing minimal Dockerfile..."
    
    # Create a minimal test Dockerfile
    $minimalDockerfile = @"
FROM alpine:latest
RUN echo "Hello World"
CMD ["echo", "Docker is working!"]
"@
    
    $minimalDockerfile | Out-File -FilePath "Dockerfile.minimal" -Encoding UTF8
    
    try {
        Write-Host "   Building minimal test image..."
        $buildOutput = docker build -f Dockerfile.minimal -t test-minimal . 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Check "Minimal Docker build works" $true
            
            # Test run
            $runOutput = docker run --rm test-minimal 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Check "Can run Docker containers" $true
                Write-Host "   Output: $runOutput"
            } else {
                Write-Check "Cannot run Docker containers" $false
            }
            
            # Cleanup
            docker rmi test-minimal 2>&1 | Out-Null
        } else {
            Write-Check "Minimal Docker build failed" $false
            Write-Host $buildOutput
        }
    }
    catch {
        Write-Check "Build test failed: $_" $false
    }
    finally {
        if (Test-Path "Dockerfile.minimal") {
            Remove-Item "Dockerfile.minimal"
        }
    }
}

function Test-NetworkConnectivity {
    Write-Step "Testing network connectivity in Docker..."
    
    try {
        $networkTest = docker run --rm alpine:latest wget -q --spider https://google.com 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Check "Network access from containers works" $true
        } else {
            Write-Check "Network access from containers failed" $false
            Write-Host $networkTest
        }
    }
    catch {
        Write-Check "Network test failed: $_" $false
    }
}

function Test-AzureCLI {
    Write-Step "Testing Azure CLI setup..."
    
    try {
        $azureTest = docker run --rm mcr.microsoft.com/azure-cli:latest az version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Check "Azure CLI image works" $true
        } else {
            Write-Check "Azure CLI image failed" $false
            Write-Host $azureTest
        }
    }
    catch {
        Write-Check "Azure CLI test failed: $_" $false
    }
}

function Show-SystemInfo {
    Write-Step "System Information..."
    
    Write-Host "Operating System: $($PSVersionTable.OS)"
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Host "Current Directory: $PWD"
    
    # Docker info
    try {
        $dockerInfo = docker info --format "{{.ServerVersion}}" 2>&1
        Write-Host "Docker Version: $dockerInfo"
        
        $dockerSpace = docker system df 2>&1
        Write-Host "Docker Disk Usage:"
        Write-Host $dockerSpace
    }
    catch {
        Write-Host "Could not get Docker info: $_"
    }
}

function Test-FilePermissions {
    Write-Step "Testing file permissions..."
    
    # Check if we can create files
    try {
        "test" | Out-File -FilePath "test-file.tmp"
        if (Test-Path "test-file.tmp") {
            Write-Check "Can create files in current directory" $true
            Remove-Item "test-file.tmp"
        } else {
            Write-Check "Cannot create files in current directory" $false
        }
    }
    catch {
        Write-Check "File creation test failed: $_" $false
    }
    
    # Check existing Dockerfiles
    $dockerfiles = @("Dockerfile", "Dockerfile.simple")
    foreach ($dockerfile in $dockerfiles) {
        if (Test-Path $dockerfile) {
            Write-Check "$dockerfile exists" $true
            $size = (Get-Item $dockerfile).Length
            Write-Host "   Size: $size bytes"
        } else {
            Write-Check "$dockerfile missing" $false
        }
    }
}

function Get-DetailedError {
    Write-Step "Getting detailed build error..."
    
    if (Test-Path "Dockerfile.simple") {
        Write-Host "Attempting build with verbose output..."
        docker build -f Dockerfile.simple -t terraform-tests-debug --progress=plain . 2>&1
    } else {
        Write-Host "Dockerfile.simple not found, creating basic one..."
        
        $basicDockerfile = @"
FROM mcr.microsoft.com/azure-cli:latest
RUN echo "Testing basic functionality"
RUN apk add --no-cache curl wget
RUN curl --version
CMD ["echo", "Build successful"]
"@
        
        $basicDockerfile | Out-File -FilePath "Dockerfile.debug" -Encoding UTF8
        docker build -f Dockerfile.debug -t terraform-tests-debug --progress=plain . 2>&1
        Remove-Item "Dockerfile.debug" -ErrorAction SilentlyContinue
    }
}

function Show-Solutions {
    Write-Step "Common Solutions..."
    
    Write-Host @"
If you're seeing build failures, try these solutions:

1. 📡 Network Issues:
   - Check if you're behind a corporate firewall
   - Try: docker build --network=host
   - Set proxy if needed: --build-arg HTTP_PROXY=http://proxy:port

2. 🔒 Permission Issues:
   - On Windows: Run PowerShell as Administrator
   - On macOS/Linux: Check Docker Desktop permissions
   - Try: docker system prune -a (cleans everything)

3. 💾 Disk Space:
   - Check available space: docker system df
   - Clean up: docker system prune -a -f
   - Increase Docker Desktop disk limit

4. 🌐 DNS Issues:
   - Try different DNS: docker run --dns=8.8.8.8 ...
   - Check corporate DNS settings

5. 🔄 Docker Issues:
   - Restart Docker Desktop
   - Reset Docker to factory defaults
   - Update Docker Desktop

6. 🚀 Alternative Approaches:
   - Use ./test-docker-simple.ps1 (simplified build)
   - Install tools locally instead of Docker
   - Use GitHub Codespaces or Azure Cloud Shell

7. 🏢 Corporate Environment:
   - Check with IT about Docker policies
   - May need approval for base images
   - Consider using internal registry

Try the simple version:
   ./test-docker-simple.ps1

Or run without Docker:
   ./run-tests.ps1 -SkipPrereqCheck
"@ -ForegroundColor Cyan
}

# Main execution
Write-Host @"
╔══════════════════════════════════════════════════════════╗
║              Docker Debug Utility                       ║
║                                                          ║
║  Diagnoses Docker build issues step by step             ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

Show-SystemInfo

if (Test-DockerBasics) {
    Test-SimpleBuild
    Test-NetworkConnectivity
    Test-AzureCLI
}

Test-FilePermissions
Get-DetailedError
Show-Solutions

Write-Host "`n🎯 Next Steps:" -ForegroundColor Green
Write-Host "1. Try: ./test-docker-simple.ps1"
Write-Host "2. Or install prerequisites locally and use: ./run-tests.ps1"
Write-Host "3. Check the solutions above for your specific issue"