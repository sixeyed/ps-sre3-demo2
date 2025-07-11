#!/usr/bin/env pwsh

# Quick K6 Test Runner for M3 Demo 1
# This script runs K6 tests using the install script in helm/k6

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

Write-Success "=========================================="
Write-Success "Running K6 Tests for M3 Demo 1"
Write-Success "=========================================="
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
        Write-Info "View test results in Grafana:"
        Write-Host "  Check the Reliability Demo dashboard for load test metrics" -ForegroundColor White
        Write-Host ""
        
        # Show current job status
        Write-Info "Current job status:"
        kubectl get jobs -n $Namespace
        Write-Host ""
        
        Write-Warning "Tests are now running. The sequence is:"
        Write-Host "  1. Soak Test (2h) - 40 constant users" -ForegroundColor Gray
        Write-Host "  2. Load Test (30m) - Ramping load 10→30→70→50→10 users" -ForegroundColor Gray  
        Write-Host "  3. Spike Test (10m) - Quick spike to 150 users" -ForegroundColor Gray
        Write-Host ""
        Write-Info "Goal: Load and Soak should pass, Spike should fail"
        
    } else {
        Write-Error "❌ Failed to start K6 tests"
        exit 1
    }
    
} finally {
    Pop-Location
}

Write-Success "K6 test execution initiated!"