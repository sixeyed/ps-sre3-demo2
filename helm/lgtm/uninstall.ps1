#!/usr/bin/env pwsh

# Uninstall script for LGTM monitoring stack
# Usage: ./uninstall.ps1 [ReleaseName] [Namespace]

param(
    [string]$ReleaseName = "lgtm-monitoring",
    [string]$Namespace = "monitoring",
    [switch]$DeleteNamespace = $false
)

# Change to script directory to ensure relative paths work
Push-Location $PSScriptRoot

Write-Host "🗑️  Uninstalling LGTM Monitoring Stack..." -ForegroundColor Red
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

# Check if release exists
$releaseExists = helm list -n $Namespace | Select-String $ReleaseName
if (-not $releaseExists) {
    Write-Host "⚠️  Release '$ReleaseName' not found in namespace '$Namespace'" -ForegroundColor Yellow
    Write-Host "Available releases:" -ForegroundColor Yellow
    helm list -n $Namespace
    exit 0
}

# Confirm deletion
Write-Host "⚠️  This will delete the following:" -ForegroundColor Yellow
Write-Host "   - Helm release: $ReleaseName" -ForegroundColor White
Write-Host "   - All monitoring data (logs, dashboards, etc.)" -ForegroundColor White
if ($DeleteNamespace) {
    Write-Host "   - Entire namespace: $Namespace" -ForegroundColor White
}
Write-Host ""

$confirmation = Read-Host "Are you sure you want to continue? (y/N)"
if ($confirmation -ne "y" -and $confirmation -ne "Y") {
    Write-Host "❌ Uninstall cancelled." -ForegroundColor Yellow
    Pop-Location
    exit 0
}

# Uninstall the Helm release
Write-Host "🔧 Uninstalling Helm release..." -ForegroundColor Blue
$uninstallResult = helm uninstall $ReleaseName -n $Namespace

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully uninstalled Helm release!" -ForegroundColor Green
    
    # Delete PVCs if they exist
    Write-Host "🧹 Cleaning up persistent volume claims..." -ForegroundColor Blue
    $pvcs = kubectl get pvc -n $Namespace -o name 2>$null
    if ($pvcs) {
        Write-Host "Found PVCs to delete:" -ForegroundColor Yellow
        $pvcs
        kubectl delete pvc --all -n $Namespace
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ PVCs deleted successfully" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Some PVCs may not have been deleted" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No PVCs found to delete" -ForegroundColor Green
    }
    
    # Delete namespace if requested
    if ($DeleteNamespace) {
        Write-Host "🧹 Deleting namespace..." -ForegroundColor Blue
        kubectl delete namespace $Namespace 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Namespace '$Namespace' deleted successfully" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Namespace '$Namespace' may not exist or couldn't be deleted" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ℹ️  Namespace '$Namespace' preserved" -ForegroundColor Blue
        Write-Host "   To delete it later, run: kubectl delete namespace $Namespace" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "✅ LGTM monitoring stack uninstalled successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Note: If you had any custom dashboards or configuration," -ForegroundColor Yellow
    Write-Host "   they have been removed. Make sure you have backups if needed." -ForegroundColor Yellow
    
} else {
    Write-Host "❌ Failed to uninstall monitoring stack" -ForegroundColor Red
    Write-Host "You may need to manually clean up resources." -ForegroundColor Yellow
    Pop-Location
    exit 1
}

# Return to original directory
Pop-Location