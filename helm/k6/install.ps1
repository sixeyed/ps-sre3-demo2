#!/usr/bin/env pwsh

# Install script for K6 test suite
# Usage: ./install.ps1 [ReleaseName] [Namespace]

param(
    [string]$ReleaseName = "k6-tests",
    [string]$Namespace = "k6",
    [switch]$CleanupFirst = $false,
    [switch]$UpdateDependencies = $false
)

# Change to script directory to ensure relative paths work
Push-Location $PSScriptRoot

Write-Host "🧪 Installing K6 Test Suite..." -ForegroundColor Blue
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

if ($CleanupFirst) {
    Write-Host "🧹 Cleaning up previous test jobs..." -ForegroundColor Yellow
    kubectl delete jobs -n $Namespace --all 2>$null
    Write-Host ""
}

# Update Helm dependencies if requested
if ($UpdateDependencies) {
    Write-Host "📦 Updating Helm dependencies..." -ForegroundColor Blue
    helm dependency update .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to update Helm dependencies" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host ""
}

# Install the K6 test suite
Write-Host "📦 Installing K6 test chart..." -ForegroundColor Green
helm upgrade --install $ReleaseName . `
    --namespace $Namespace `
    --create-namespace `
    --wait `
    --timeout 10m

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ K6 Test Suite installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Monitor test progress:" -ForegroundColor Cyan
    Write-Host "  kubectl logs -n $Namespace -l k6.test/type=sequential -f" -ForegroundColor White
    Write-Host ""
    Write-Host "🔍 Check job status:" -ForegroundColor Cyan 
    Write-Host "  kubectl get jobs -n $Namespace" -ForegroundColor White
    Write-Host ""
    Write-Host "📈 View results in Grafana:" -ForegroundColor Cyan
    Write-Host "  http://localhost:3000/d/reliability-demo-logs/reliability-demo-log-analytics" -ForegroundColor White
} else {
    Write-Host "❌ Installation failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Return to original directory
Pop-Location