#!/usr/bin/env pwsh

# Install script for Reliability Demo Helm chart
# Usage: ./install.ps1 [ReleaseName] [Namespace]

param(
    [string]$ReleaseName = "reliability-demo",
    [string]$Namespace = "sre3-m1"
)

Write-Host "Installing Reliability Demo Helm chart..." -ForegroundColor Blue
Write-Host "Release: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

# Update Helm dependencies
Write-Host "Updating Helm dependencies..." -ForegroundColor Blue
helm dependency update

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to update Helm dependencies" -ForegroundColor Red
    exit 1
}

# Install the chart
Write-Host "Installing chart..." -ForegroundColor Blue
helm upgrade --install $ReleaseName . `
  --namespace $Namespace `
  --create-namespace `
  --wait `
  --timeout=600s

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
    exit 1
}