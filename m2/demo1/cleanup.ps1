#!/usr/bin/env pwsh

# Demo 1 Cleanup Script
# Removes the test cluster and cleans up Docker resources

param(
    [string]$ClusterName = "sre3-m2"
)

Write-Host "=== Demo 1 Cleanup ===" -ForegroundColor Red
Write-Host ""

# Delete k3d cluster
Write-Host "Deleting k3d cluster '$ClusterName'..." -ForegroundColor Yellow
k3d cluster delete $ClusterName

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Cluster deleted successfully" -ForegroundColor Green
} else {
    Write-Warning "Failed to delete cluster or cluster didn't exist"
}

# Clean up any dangling images and containers
Write-Host "Cleaning up dangling Docker resources..." -ForegroundColor Yellow
docker system prune -f | Out-Null

Write-Host "✓ Docker cleanup complete" -ForegroundColor Green
Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Green
Write-Host "The test environment has been removed." -ForegroundColor White