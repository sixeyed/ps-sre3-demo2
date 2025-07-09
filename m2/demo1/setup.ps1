#!/usr/bin/env pwsh

# Demo 1 Setup Script - Manual Deployment Anti-Patterns Test Environment
# Creates a 3-node k3d cluster with older Kubernetes version

param(
    [string]$ClusterName = "sre3-m2",
    [string]$KubernetesVersion = "v1.24.2-k3s1",
    [int]$ApiPort = 6551,
    [int]$HttpPort = 8080,
    [int]$GrafanaPort = 3000,
    [int]$RegistryPort = 5001
)

Write-Host "=== Demo 1 Setup: Creating Test Environment ===" -ForegroundColor Green
Write-Host ""

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

if (-not (Test-Command "docker")) {
    Write-Error "Docker is not installed or not in PATH"
    exit 1
}

if (-not (Test-Command "k3d")) {
    Write-Error "k3d is not installed or not in PATH"
    exit 1
}

if (-not (Test-Command "kubectl")) {
    Write-Error "kubectl is not installed or not in PATH"
    exit 1
}

# Check if Docker is running
try {
    docker info | Out-Null
    Write-Host "✓ Docker is running" -ForegroundColor Green
}
catch {
    Write-Error "Docker is not running. Please start Docker Desktop."
    exit 1
}

Write-Host "✓ k3d is available" -ForegroundColor Green
Write-Host "✓ kubectl is available" -ForegroundColor Green
Write-Host ""

# Clean up existing cluster if it exists
Write-Host "Cleaning up any existing cluster..." -ForegroundColor Yellow
k3d cluster delete $ClusterName 2>$null

# Create k3d cluster with older Kubernetes version and resource constraints
Write-Host "Creating k3d cluster with Kubernetes $KubernetesVersion..." -ForegroundColor Yellow
Write-Host "Cluster name: $ClusterName" -ForegroundColor Cyan
Write-Host "API port: $ApiPort" -ForegroundColor Cyan
Write-Host "HTTP port: $HttpPort" -ForegroundColor Cyan
Write-Host "Registry port: $RegistryPort" -ForegroundColor Cyan
Write-Host "Resource limits: 1.5GB per worker, 1GB for control plane" -ForegroundColor Yellow
Write-Host "Control plane scheduling: Disabled (NoSchedule taint)" -ForegroundColor Yellow

$clusterCommand = @(
    "k3d", "cluster", "create", $ClusterName,
    "--image", "rancher/k3s:$KubernetesVersion",
    "--api-port", $ApiPort,
    "--servers", "1",
    "--agents", "3",
    "--port", "$HttpPort`:$HttpPort@loadbalancer",
    "--port", "$GrafanaPort`:$GrafanaPort@loadbalancer",
    "--registry-create", "test.registry:$RegistryPort",
    "--agents-memory", "1.5g",
    "--servers-memory", "1g",
    "--k3s-arg", "--node-taint=CriticalAddonsOnly=true:NoSchedule@server:*"
)

Write-Host "Running: $($clusterCommand -join ' ')" -ForegroundColor Gray
& $clusterCommand[0] $clusterCommand[1..$clusterCommand.Length]

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create k3d cluster"
    exit 1
}

Write-Host "✓ Cluster created successfully" -ForegroundColor Green
Write-Host ""

# Wait for cluster to be ready
Write-Host "Waiting for cluster to be ready..." -ForegroundColor Yellow
$timeout = 60
$elapsed = 0

do {
    Start-Sleep -Seconds 2
    $elapsed += 2
    $nodes = kubectl get nodes --no-headers 2>$null
    $readyNodes = ($nodes | Where-Object { $_ -match "Ready" }).Count
    
    if ($readyNodes -eq 4) { # 1 server + 3 agents
        Write-Host "✓ All nodes are ready" -ForegroundColor Green
        break
    }
    
    if ($elapsed -ge $timeout) {
        Write-Error "Timeout waiting for cluster to be ready"
        exit 1
    }
    
    Write-Host "Waiting for nodes to be ready... ($elapsed/$timeout seconds)" -ForegroundColor Gray
} while ($true)

# Verify cluster version
Write-Host ""
Write-Host "Verifying cluster version..." -ForegroundColor Yellow
kubectl get nodes -o wide

Start-Sleep -Seconds 10

Write-Host "Deploying logging subsystem..." -ForegroundColor Yellow
../../helm/lgtm/install.ps1


Write-Host "Deploying app..." -ForegroundColor Yellow
kubectl apply -f manifests/initial

# Prepare container images
Write-Host "Testing registry ..." -ForegroundColor Yellow

$imageTag = "test.registry:5001/reliability-demo:m2"

Write-Host "Building web image with tag: $imageTag"
Push-Location ../../src

# Build new container image
docker build -t $imageTag -f ReliabilityDemo/Dockerfile .

# Push to test registry
docker push $imageTag

Write-Host "Image pushed successfully: $imageTag"
Pop-Location


Write-Host "✓ Container images prepared" -ForegroundColor Green
Write-Host ""

# Verify setup
Write-Host "Verifying setup..." -ForegroundColor Yellow

Write-Host "Cluster nodes:" -ForegroundColor Cyan
kubectl get nodes

Write-Host ""
Write-Host "Checking for existing reliability-demo namespace:" -ForegroundColor Cyan
$namespace = kubectl get namespaces | Select-String "reliability-demo"
if ($namespace) {
    Write-Host "Found: $namespace" -ForegroundColor Red
} else {
    Write-Host "✓ No existing reliability-demo namespace" -ForegroundColor Green
}

Write-Host ""
Write-Host "Registry catalog:" -ForegroundColor Cyan
try {
    $catalog = Invoke-RestMethod -Uri "http://test.registry:$RegistryPort/v2/_catalog" -TimeoutSec 5
    Write-Host "✓ Registry accessible at test.registry:$RegistryPort" -ForegroundColor Green
    Write-Host "Available repositories:" -ForegroundColor Gray
    $catalog.repositories | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
}
catch {
    # Try localhost as fallback
    try {
        $catalog = Invoke-RestMethod -Uri "http://localhost:$RegistryPort/v2/_catalog" -TimeoutSec 5
        Write-Host "✓ Registry accessible at localhost:$RegistryPort" -ForegroundColor Green
        Write-Host "Note: Add 'test.registry' to your hosts file pointing to 127.0.0.1" -ForegroundColor Yellow
    }
    catch {
        Write-Warning "Could not verify registry catalog: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Your test environment is ready with:" -ForegroundColor White
Write-Host "• Kubernetes version: $KubernetesVersion (outdated/unsupported)" -ForegroundColor Yellow
Write-Host "• 4 nodes: 1 server + 3 agents" -ForegroundColor Yellow
Write-Host "• Local registry: test.registry:$RegistryPort" -ForegroundColor Yellow
Write-Host "• Application port: localhost:$HttpPort" -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANT: Add this line to your hosts file:" -ForegroundColor Red
Write-Host "127.0.0.1    test.registry" -ForegroundColor Cyan
Write-Host ""
Write-Host "To run the demo:" -ForegroundColor White
Write-Host "  ./run-demo.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "To clean up when done:" -ForegroundColor White
Write-Host "  ./cleanup.ps1" -ForegroundColor Cyan
Write-Host ""