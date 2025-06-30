#!/usr/bin/env pwsh

# Build and push script for reliability-demo Docker images

Write-Host "Building Docker images"
$buildResult = docker compose build

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful! Pushing to Docker Hub..." -ForegroundColor Green
    $pushResult = docker compose push
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully pushed " -ForegroundColor Green
        Write-Host ""
        Write-Host "To deploy to Kubernetes:" -ForegroundColor Yellow
        Write-Host "  helm/app/install.ps1" -ForegroundColor Yellow
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