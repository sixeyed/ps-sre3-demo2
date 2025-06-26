#!/usr/bin/env pwsh

# Install script for LGTM monitoring stack
# Usage: ./install.ps1 [ReleaseName] [Namespace]

param(
    [string]$ReleaseName = "lgtm-monitoring",
    [string]$Namespace = "monitoring"
)

Write-Host "🚀 Installing LGTM Monitoring Stack..." -ForegroundColor Blue
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

# Update Helm dependencies
Write-Host "📦 Updating Helm dependencies..." -ForegroundColor Blue
$depResult = helm dependency update .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to update Helm dependencies" -ForegroundColor Red
    exit 1
}

# Install or upgrade the release
Write-Host "🔧 Installing/upgrading Helm release..." -ForegroundColor Blue
$installResult = helm upgrade --install $ReleaseName . `
    --namespace $Namespace `
    --create-namespace `
    --wait `
    --timeout 10m

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully installed LGTM monitoring stack!" -ForegroundColor Green
    Write-Host ""
    
    # Show status
    Write-Host "📊 Monitoring Stack Status:" -ForegroundColor Yellow
    kubectl get pods -n $Namespace
    Write-Host ""
    
    # Show service information
    Write-Host "🌐 Services:" -ForegroundColor Yellow
    kubectl get svc -n $Namespace
    Write-Host ""
    
    # Wait for Grafana to be ready
    Write-Host "⏳ Waiting for Grafana to be ready..." -ForegroundColor Blue
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n $Namespace --timeout=300s
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Grafana is ready!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
        Write-Host "1. Access Grafana:" -ForegroundColor White
        Write-Host "   kubectl port-forward -n $Namespace svc/grafana 3000:3000" -ForegroundColor Cyan
        Write-Host "   Then open: http://localhost:3000" -ForegroundColor Cyan
        Write-Host "   Login: admin / admin123" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "2. View application logs:" -ForegroundColor White
        Write-Host "   - Go to Explore in Grafana" -ForegroundColor Cyan
        Write-Host "   - Select Loki datasource" -ForegroundColor Cyan
        Write-Host "   - Query: {namespace=`"sre3-m1`"}" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "3. Deploy your application to start seeing logs:" -ForegroundColor White
        Write-Host "   cd ../helm-chart && ./install.ps1" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️  Grafana may still be starting up. Check status with:" -ForegroundColor Yellow
        Write-Host "   kubectl get pods -n $Namespace" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ Failed to install monitoring stack" -ForegroundColor Red
    Write-Host "Check the error messages above and try again." -ForegroundColor Yellow
    exit 1
}