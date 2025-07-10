# Module 3 Demo 1 - Static Infrastructure Setup
# This script deploys the oversized static infrastructure for the demo

param([switch]$Force)

Write-Host "Module 3 Demo 1 - Static Infrastructure Setup" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Check prerequisites
Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow

# Check gh CLI
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: GitHub CLI (gh) is not installed" -ForegroundColor Red
    Write-Host "Install from: https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

# Check if authenticated
$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Not authenticated with GitHub CLI" -ForegroundColor Red
    Write-Host "Run: gh auth login" -ForegroundColor Yellow
    exit 1
}

# Configuration
$repo = "sixeyed/ps-sre3-demo2"
$workflow = "deploy-infrastructure.yml"
$environment = "production"
$action = "apply"

Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  Repository: $repo"
Write-Host "  Workflow: $workflow"
Write-Host "  Environment: $environment"
Write-Host "  Terraform Action: $action"

# Confirm deployment
Write-Host "`nThis will deploy expensive static infrastructure to Azure!" -ForegroundColor Yellow
Write-Host "The demo will show high costs and poor utilization." -ForegroundColor Yellow

if (-not $Force) {
    $confirm = Read-Host "`nDo you want to continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "`nDeployment cancelled" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "`nForce flag detected - proceeding with deployment" -ForegroundColor Green
}

# Trigger workflow
Write-Host "`nTriggering infrastructure deployment..." -ForegroundColor Green

try {
    # Run the workflow with parameters
    gh workflow run $workflow `
        --repo $repo `
        --field environment=$environment `
        --field action=$action

    Write-Host "Workflow triggered successfully!" -ForegroundColor Green
    
    # Wait a moment for the run to register
    Start-Sleep -Seconds 3
    
    # Get the latest workflow run
    $latestRun = gh run list `
        --repo $repo `
        --workflow $workflow `
        --limit 1 `
        --json databaseId,status,conclusion,url | ConvertFrom-Json
    
    if ($latestRun) {
        $runId = $latestRun[0].databaseId
        $runUrl = $latestRun[0].url
        
        Write-Host "`nWorkflow Details:" -ForegroundColor Cyan
        Write-Host "  Run ID: $runId"
        Write-Host "  Status: $($latestRun[0].status)"
        Write-Host "  URL: $runUrl"
        
        Write-Host "`nMonitoring deployment..." -ForegroundColor Yellow
        Write-Host "Press Ctrl+C to stop monitoring (workflow will continue running)`n"
        
        # Monitor the workflow
        gh run watch $runId --repo $repo --exit-status
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nInfrastructure deployed successfully!" -ForegroundColor Green
            
            Write-Host "`nGetting AKS credentials..." -ForegroundColor Yellow
            try {
                az aks get-credentials --resource-group ps-sre3-demo-prod --name ps-sre3-demo-prod-aks --overwrite-existing
                
                Write-Host "`nVerifying cluster access..." -ForegroundColor Yellow
                kubectl get nodes
                
                Write-Host "`nChecking application status..." -ForegroundColor Yellow
                kubectl get pods -n reliability-demo
                
                Write-Host "`nWaiting for load balancer IP..." -ForegroundColor Yellow
                $maxAttempts = 30
                $webAppIP = $null
                
                for ($i = 1; $i -le $maxAttempts; $i++) {
                    $webAppIP = kubectl get svc reliability-demo-web -n reliability-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
                    if ($webAppIP -and $webAppIP -ne "null" -and $webAppIP.Trim() -ne "") {
                        break
                    }
                    Write-Host "Waiting for load balancer IP... (attempt $i/$maxAttempts)"
                    Start-Sleep -Seconds 10
                }
                
                if ($webAppIP -and $webAppIP -ne "null" -and $webAppIP.Trim() -ne "") {
                    Write-Host "`nLoad balancer IP: $webAppIP" -ForegroundColor Green
                    $webAppUrl = "http://$webAppIP"
                    Write-Host "Application URL: $webAppUrl" -ForegroundColor Green
                    
                    Write-Host "`nTesting application..." -ForegroundColor Yellow
                    $maxTestAttempts = 10
                    $appWorking = $false
                    
                    for ($j = 1; $j -le $maxTestAttempts; $j++) {
                        try {
                            $response = Invoke-WebRequest -Uri $webAppUrl -Method GET -TimeoutSec 10
                            if ($response.StatusCode -eq 200) {
                                Write-Host "Application is responding successfully!" -ForegroundColor Green
                                $appWorking = $true
                                break
                            }
                        } catch {
                            Write-Host "Testing application... (attempt $j/$maxTestAttempts)"
                            Start-Sleep -Seconds 15
                        }
                    }
                    
                    if ($appWorking) {
                        Write-Host "`nDemo setup complete!" -ForegroundColor Green
                        Write-Host "✓ Infrastructure deployed" -ForegroundColor Green
                        Write-Host "✓ Application responding at: $webAppUrl" -ForegroundColor Green
                        
                        Write-Host "`nAccess URLs:" -ForegroundColor Cyan
                        Write-Host "• Web App: $webAppUrl" -ForegroundColor White
                        Write-Host "• Monitoring: kubectl port-forward -n monitoring svc/grafana 3000:80" -ForegroundColor White
                        
                        Write-Host "`nMonitoring commands:" -ForegroundColor Cyan
                        Write-Host "• Resource usage: kubectl top nodes" -ForegroundColor White
                        Write-Host "• Pod status: kubectl get pods -n reliability-demo" -ForegroundColor White
                        Write-Host "• Load balancer: kubectl get svc -n reliability-demo" -ForegroundColor White
                    } else {
                        Write-Host "`nApplication is not responding properly." -ForegroundColor Red
                        Write-Host "Check the application logs:" -ForegroundColor Yellow
                        Write-Host "kubectl logs -l app=reliability-demo -n reliability-demo" -ForegroundColor White
                    }
                } else {
                    Write-Host "`nLoad balancer IP not assigned within timeout." -ForegroundColor Red
                    Write-Host "You can check manually:" -ForegroundColor Yellow
                    Write-Host "kubectl get svc reliability-demo-web -n reliability-demo" -ForegroundColor White
                }
            } catch {
                Write-Host "`nError during verification: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Manual verification commands:" -ForegroundColor Yellow
                Write-Host "az aks get-credentials --resource-group ps-sre3-demo-prod --name ps-sre3-demo-prod-aks" -ForegroundColor White
                Write-Host "kubectl get nodes" -ForegroundColor White
                Write-Host "kubectl get pods -n reliability-demo" -ForegroundColor White
            }
        } else {
            Write-Host "`nWorkflow failed! Check the logs:" -ForegroundColor Red
            Write-Host $runUrl -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "`nERROR: Failed to trigger workflow" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nTry running manually:" -ForegroundColor Yellow
    Write-Host "gh workflow run $workflow --repo $repo --field environment=$environment --field action=$action" -ForegroundColor Gray
    exit 1
}

Write-Host "`nSetup complete!" -ForegroundColor Green
Write-Host "`nREMEMBER: This infrastructure is expensive!" -ForegroundColor Yellow
Write-Host "Run the cleanup script when the demo is complete." -ForegroundColor Yellow

Write-Host "`nIf you encounter Terraform state lock issues:" -ForegroundColor Yellow
Write-Host "Run: gh workflow run deploy-infrastructure.yml --repo sixeyed/ps-sre3-demo2 --field environment=production --field action=destroy" -ForegroundColor White