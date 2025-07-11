#!/usr/bin/env pwsh

# K6 Test Runner for M3 Demo 2 - Using Same Tests as Demo 1
# This script runs the EXACT SAME K6 tests from Demo 1 to prove KEDA autoscaling fixes the issues

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

Write-Success "=================================================================="
Write-Success "Running Demo 1 K6 Tests on Demo 2 Infrastructure (KEDA Enabled)"
Write-Success "=================================================================="
Write-Info "🎯 Goal: Prove SAME tests that failed in Demo 1 now pass with KEDA!"
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
        Write-Info "Monitor KEDA scaling in real-time:"
        Write-Host "  kubectl get scaledobjects -n reliability-demo -w" -ForegroundColor White
        Write-Host "  kubectl get hpa -n reliability-demo -w" -ForegroundColor White
        Write-Host ""
        Write-Info "View scaling events:"
        Write-Host "  kubectl get events -n reliability-demo --sort-by=.metadata.creationTimestamp" -ForegroundColor White
        Write-Host ""
        
        # Show current job status
        Write-Info "Current job status:"
        kubectl get jobs -n $Namespace
        Write-Host ""
        
        Write-Warning "📊 Same Test Sequence as Demo 1:"
        Write-Host "  1. Soak Test (10m) - 40 constant users" -ForegroundColor Gray
        Write-Host "  2. Load Test (5m) - Ramping load 10→30→70→50→10 users" -ForegroundColor Gray  
        Write-Host "  3. Spike Test (5m) - Quick spike to 600 users" -ForegroundColor Gray
        Write-Host ""
        Write-Success "🎯 Expected Demo 2 Results with KEDA:"
        Write-Host "  ✅ Soak Test: PASS (HTTP metrics trigger pod scaling)" -ForegroundColor Green
        Write-Host "  ✅ Load Test: PASS (Queue depth triggers worker scaling)" -ForegroundColor Green
        Write-Host "  ✅ Spike Test: PASS (Rapid scaling handles 600 users!)" -ForegroundColor Green
        Write-Host ""
        Write-Info "💰 Same tests, 85% cost reduction vs Demo 1 static infrastructure"
        
    } else {
        Write-Error "❌ Failed to start K6 tests"
        exit 1
    }
    
} finally {
    Pop-Location
}

Write-Success "Demo 1 tests running on Demo 2 KEDA infrastructure!"