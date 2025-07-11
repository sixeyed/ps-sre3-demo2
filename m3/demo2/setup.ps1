# Module 3 Demo 2 - Dynamic Scaling Setup
# This script deploys infrastructure with KEDA autoscaling using GitHub Actions

param([switch]$Force)

Write-Host "Module 3 Demo 2 - Dynamic Scaling Setup" -ForegroundColor Green
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
$profile = "m3demo2"

Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  Repository: $repo"
Write-Host "  Workflow: $workflow"
Write-Host "  Environment: $environment"
Write-Host "  Action: $action"
Write-Host "  Profile: $profile (dynamic scaling with KEDA)"

Write-Host "`nThis will deploy:" -ForegroundColor Yellow
Write-Host "  • AKS cluster with D4 VMs and autoscaling (2-7 nodes per pool)"
Write-Host "  • KEDA for event-driven autoscaling"
Write-Host "  • Right-sized application pods (2 CPU, 4GB vs 6 CPU, 12GB)"
Write-Host "  • HTTP-based scaling for web pods"
Write-Host "  • Redis queue-based scaling for workers"

if (-not $Force) {
    $confirm = Read-Host "`nProceed with Demo 2 deployment? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "`nDeployment cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Trigger workflow
Write-Host "`nTriggering infrastructure deployment..." -ForegroundColor Green

try {
    # Run the workflow with m3demo2 profile
    gh workflow run $workflow `
        --repo $repo `
        --field environment=$environment `
        --field action=$action `
        --field profile=$profile

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
            
            Write-Host "`nNext Steps:" -ForegroundColor Cyan
            Write-Host "1. Run K6 tests to validate KEDA autoscaling:"
            Write-Host "   ./run-k6-tests.ps1" -ForegroundColor White
            Write-Host ""
            Write-Host "2. Monitor scaling in Grafana dashboard"
            Write-Host "3. Check KEDA ScaledObjects:"
            Write-Host "   kubectl get scaledobjects -n reliability-demo" -ForegroundColor White
            Write-Host ""
            Write-Host "Expected Results:" -ForegroundColor Yellow
            Write-Host "  • Soak Test: ✅ PASS (40 VUs, automatic pod scaling)"
            Write-Host "  • Load Test: ✅ PASS (70 VUs, queue-based worker scaling)"  
            Write-Host "  • Spike Test: ✅ PASS (600 VUs, rapid HTTP-based scaling)"
            Write-Host ""
            Write-Host "Demo 2 shows same tests that failed in Demo 1 now succeed!" -ForegroundColor Green
            
        } else {
            Write-Host "`nWorkflow failed! Check the logs:" -ForegroundColor Red
            Write-Host $runUrl -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "`nERROR: Failed to trigger workflow" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nTry running manually:" -ForegroundColor Yellow
    Write-Host "gh workflow run $workflow --repo $repo --field environment=$environment --field action=$action --field profile=$profile" -ForegroundColor Gray
    exit 1
}

Write-Host "`nSetup script complete!" -ForegroundColor Green