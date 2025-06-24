#!/usr/bin/env pwsh

# Build and push script for reliability-demo Docker image
# Usage: ./build-and-push.ps1 [tag]

param(
    [string]$Tag = "m1-01"
)

$ImageName = "sixeyed/reliability-demo"
$FullImage = "${ImageName}:${Tag}"

Write-Host "Building Docker image: $FullImage" -ForegroundColor Blue
$buildResult = docker build -t $FullImage src/ReliabilityDemo/

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful! Pushing to Docker Hub..." -ForegroundColor Green
    $pushResult = docker push $FullImage
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully pushed $FullImage" -ForegroundColor Green
        Write-Host ""
        Write-Host "To deploy to Kubernetes:" -ForegroundColor Yellow
        Write-Host "  cd helm-chart" -ForegroundColor Yellow
        Write-Host "  ./install.ps1" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To run with Docker Compose:" -ForegroundColor Yellow
        Write-Host "  docker-compose up" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Failed to push image to Docker Hub" -ForegroundColor Red
        Write-Host "Make sure you're logged in: docker login" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "❌ Docker build failed" -ForegroundColor Red
    exit 1
}