# Module 3 Demo 2 - Dynamic Scaling Cleanup
# This script destroys the demo infrastructure using GitHub Actions

param([switch]$Force)

Write-Host "Module 3 Demo 2 - Dynamic Scaling Cleanup" -ForegroundColor Red
Write-Host "===========================================" -ForegroundColor Red

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
$action = "destroy"

Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  Repository: $repo"
Write-Host "  Workflow: $workflow"
Write-Host "  Environment: $environment"
Write-Host "  Action: $action"

# Confirm destruction
Write-Host "`nWARNING: This will destroy all Demo 2 infrastructure!" -ForegroundColor Red
Write-Host "This action cannot be undone." -ForegroundColor Red

if (-not $Force) {
    $confirm = Read-Host "`nAre you sure you want to continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "`nCleanup cancelled" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "`nForce flag detected - proceeding with destruction" -ForegroundColor Red
}

# Trigger workflow
Write-Host "`nTriggering infrastructure destruction..." -ForegroundColor Red

try {
    # Run the workflow with destroy action
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
        
        Write-Host "`nMonitoring destruction..." -ForegroundColor Yellow
        Write-Host "Press Ctrl+C to stop monitoring (workflow will continue running)`n"
        
        # Monitor the workflow
        gh run watch $runId --repo $repo --exit-status
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nInfrastructure destroyed successfully!" -ForegroundColor Green
            
            # Clean up local kubectl context
            Write-Host "`nCleaning up local kubectl context..." -ForegroundColor Yellow
            try {
                kubectl config delete-context aks-reliability-demo-production 2>$null
                kubectl config delete-cluster aks-reliability-demo-production 2>$null
                kubectl config delete-user clusterUser_reliability-demo-production_aks-reliability-demo-production 2>$null
                Write-Host "✓ kubectl context cleaned up" -ForegroundColor Green
            } catch {
                Write-Host "Note: kubectl context cleanup skipped (may not exist)" -ForegroundColor Gray
            }
            
            Write-Host "`nCleanup complete!" -ForegroundColor Green
            Write-Host "You can now run the setup script to redeploy." -ForegroundColor Cyan
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

Write-Host "`nCleanup script complete!" -ForegroundColor Green