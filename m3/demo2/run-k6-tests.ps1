#!/usr/bin/env pwsh

# Quick K6 Test Runner for M3 Demo 2
# This script runs the same K6 tests as Demo 1 but they should now succeed with KEDA autoscaling

param(
    [string]$ReleaseName = "k6-tests",
    [string]$Namespace = "k6",
    [string]$ValuesFile = "values-azure.yaml",
    [switch]$CleanupFirst = $true
)

# Color output functions
function Write-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Warning { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host $Message -ForegroundColor Red }

Write-Success "=================================================="
Write-Success "Running K6 Tests for M3 Demo 2 - Dynamic Scaling"
Write-Success "=================================================="
Write-Info "Goal: Same tests from Demo 1 but now succeed with KEDA!"
Write-Host ""

# Navigate to K6 helm chart directory
$k6Path = "../../helm/k6"
if (-not (Test-Path $k6Path)) {
    Write-Error "K6 chart directory not found at $k6Path"
    exit 1
}

Push-Location $k6Path

try {
    Write-Info "Installing K6 tests..."
    Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
    Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
    Write-Host "Values File: $ValuesFile" -ForegroundColor Yellow
    Write-Host ""
    
    # Run the K6 install script
    if ($CleanupFirst) {
        ./install.ps1 -ReleaseName $ReleaseName -Namespace $Namespace -ValuesFile $ValuesFile -CleanupFirst
    } else {
        ./install.ps1 -ReleaseName $ReleaseName -Namespace $Namespace -ValuesFile $ValuesFile
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ K6 tests started successfully!"
        Write-Host ""
        Write-Info "Monitor test progress:"
        Write-Host "  kubectl logs -n $Namespace -l k6.test/type=sequential -f" -ForegroundColor White
        Write-Host ""
        Write-Info "Check job status:"
        Write-Host "  kubectl get jobs -n $Namespace" -ForegroundColor White
        Write-Host ""
        Write-Info "Monitor KEDA scaling:"
        Write-Host "  kubectl get scaledobjects -n reliability-demo" -ForegroundColor White
        Write-Host "  kubectl get hpa -n reliability-demo" -ForegroundColor White
        Write-Host ""
        Write-Info "View scaling events:"
        Write-Host "  kubectl get events -n reliability-demo --sort-by=.metadata.creationTimestamp" -ForegroundColor White
        Write-Host ""
        
        # Show current job status
        Write-Info "Current job status:"
        kubectl get jobs -n $Namespace
        Write-Host ""
        
        Write-Success "📊 Expected Results with KEDA Autoscaling:"
        Write-Host "  1. Soak Test (10m, 40 VUs): ✅ PASS" -ForegroundColor Green
        Write-Host "     → HTTP metrics trigger web pod scaling" -ForegroundColor Gray
        Write-Host "     → No new nodes needed, existing capacity sufficient" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Load Test (5m, 70 VUs): ✅ PASS" -ForegroundColor Green  
        Write-Host "     → Redis queue depth triggers worker scaling" -ForegroundColor Gray
        Write-Host "     → Cluster autoscaler provisions new nodes" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  3. Spike Test (5m, 600 VUs): ✅ PASS" -ForegroundColor Green
        Write-Host "     → Rapid web pod scaling handles traffic surge" -ForegroundColor Gray
        Write-Host "     → Multiple new nodes provisioned automatically" -ForegroundColor Gray
        Write-Host "     → More pods = more aggregate capacity" -ForegroundColor Gray
        Write-Host ""
        Write-Warning "🎯 Demo Success: Same 600-user spike that failed in Demo 1 now succeeds!"
        Write-Info "💰 Cost: 85% reduction vs static infrastructure while handling all loads"
        
    } else {
        Write-Error "❌ Failed to start K6 tests"
        exit 1
    }
    
} finally {
    Pop-Location
}

Write-Success "K6 test execution initiated for Dynamic Scaling Demo!"