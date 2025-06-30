#!/usr/bin/env pwsh

# Install script for Reliability Demo Helm chart
# Usage: ./install.ps1 [ReleaseName] [Namespace] [Pattern]

param(
    [string]$ReleaseName = "reliability-demo",
    [string]$Namespace = "sre3-m1",
    [string]$Pattern = "Direct",  # "Direct" or "Async"
    [switch]$UpdateDependencies = $false
)

# Change to script directory to ensure relative paths work
Push-Location $PSScriptRoot

Write-Host "Installing Reliability Demo Helm chart..." -ForegroundColor Blue
Write-Host "Release: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host "Pattern: $Pattern" -ForegroundColor Yellow
Write-Host ""

# Update Helm dependencies if requested
if ($UpdateDependencies) {
    Write-Host "Updating Helm dependencies..." -ForegroundColor Blue
    helm dependency update

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to update Helm dependencies" -ForegroundColor Red
        Pop-Location
        exit 1
    }
}

# Install the chart
Write-Host "Installing chart..." -ForegroundColor Blue
helm upgrade --install $ReleaseName . `
  --namespace $Namespace `
  --create-namespace `
  --wait `
  --timeout=600s `
  --set config.customerOperation.pattern=$Pattern

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Installation successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Get the application status:" -ForegroundColor Yellow
    Write-Host "  helm status $ReleaseName -n $Namespace" -ForegroundColor White
    Write-Host ""
    Write-Host "Scale the application:" -ForegroundColor Yellow
    Write-Host "  helm upgrade $ReleaseName . --set replicaCount=10 -n $Namespace" -ForegroundColor White
    Write-Host ""
    Write-Host "Uninstall:" -ForegroundColor Yellow
    Write-Host "  helm uninstall $ReleaseName -n $Namespace" -ForegroundColor White
} else {
    Write-Host "❌ Installation failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Return to original directory
Pop-Location