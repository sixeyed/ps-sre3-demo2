#!/usr/bin/env pwsh

# Demo 1 Cleanup Script
# Removes the test cluster and cleans up Docker resources

param(
    [string]$ClusterName = "test-cluster"
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

# Clean up Docker images
Write-Host ""
Write-Host "Cleaning up Docker images..." -ForegroundColor Yellow

# Remove test registry images
$testImages = @(
    "test.registry:5001/reliability-demo:2024-01-14-1200",
    "test.registry:5001/reliability-demo:2024-01-14-1630",
    "test.registry:5001/reliability-demo:2024-01-15-0900",
    "test.registry:5001/reliability-demo:broken-test"
)

foreach ($image in $testImages) {
    Write-Host "Removing $image..." -ForegroundColor Gray
    docker rmi $image 2>$null
}

# Clean up any dangling images and containers
Write-Host "Cleaning up dangling Docker resources..." -ForegroundColor Yellow
docker system prune -f | Out-Null

Write-Host "✓ Docker cleanup complete" -ForegroundColor Green
Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Green
Write-Host "The test environment has been removed." -ForegroundColor White