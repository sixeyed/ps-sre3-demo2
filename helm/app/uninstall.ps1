#!/usr/bin/env pwsh

# Uninstall script for Reliability Demo Helm chart
# Usage: ./uninstall.ps1 [ReleaseName] [Namespace]

param(
    [string]$ReleaseName = "reliability-demo",
    [string]$Namespace = "sre3-m1"
)

# Change to script directory to ensure relative paths work
Push-Location $PSScriptRoot

Write-Host "Uninstalling Reliability Demo Helm chart..." -ForegroundColor Blue
Write-Host "Release: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

# Uninstall the chart
helm uninstall $ReleaseName --namespace $Namespace

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Uninstallation successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: PersistentVolumes may still exist and need manual cleanup if desired." -ForegroundColor Yellow
    Write-Host "Check with: kubectl get pv" -ForegroundColor White
} else {
    Write-Host "❌ Uninstallation failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Return to original directory
Pop-Location