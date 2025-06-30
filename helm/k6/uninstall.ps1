#!/usr/bin/env pwsh

# Uninstall script for K6 test suite
# Usage: ./uninstall.ps1 [ReleaseName] [Namespace]

param(
    [string]$ReleaseName = "k6-tests",
    [string]$Namespace = "k6",
    [switch]$DeleteNamespace = $false
)

# Change to script directory to ensure relative paths work
Push-Location $PSScriptRoot

Write-Host "🧹 Uninstalling K6 Test Suite..." -ForegroundColor Blue
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

# Clean up any running or completed jobs
Write-Host "🗑️  Cleaning up test jobs..." -ForegroundColor Yellow
kubectl delete jobs -n $Namespace --all 2>$null

# Uninstall the Helm release
Write-Host "📦 Uninstalling Helm release..." -ForegroundColor Yellow
helm uninstall $ReleaseName --namespace $Namespace

if ($DeleteNamespace) {
    Write-Host "🗑️  Deleting namespace..." -ForegroundColor Yellow
    kubectl delete namespace $Namespace 2>$null
}

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ K6 Test Suite uninstalled successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Uninstallation encountered issues!" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Return to original directory
Pop-Location