#!/usr/bin/env pwsh

# K6 Test Iteration Script for M3 Demo 1
# This script runs K6 tests with different configurations to achieve:
# - Load and soak tests pass
# - Spike test fails (demonstrates system limits)

param(
    [int]$StartIteration = 1,
    [int]$MaxIterations = 10,
    [switch]$CleanupBetweenRuns = $true
)

# Color output functions
function Write-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Warning { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host $Message -ForegroundColor Red }

Write-Success "=========================================="
Write-Success "K6 Test Iteration Script for M3 Demo 1"
Write-Success "=========================================="
Write-Info "Goal: Load/Soak tests pass, Spike test fails"
Write-Host ""

# Test parameter configurations to try
# We'll increase spike test intensity while keeping load/soak manageable
$testConfigurations = @(
    @{
        Name = "Baseline"
        Description = "Current Azure configuration"
        SoakVUs = 40
        LoadMaxTarget = 70
        SpikeMaxTarget = 150
        SpikeRampDuration = "30s"
        SpikeSustainDuration = "6m"
    },
    @{
        Name = "Spike Intensity +20%"
        Description = "Increase spike target to 180 users"
        SoakVUs = 40
        LoadMaxTarget = 70
        SpikeMaxTarget = 180
        SpikeRampDuration = "30s"
        SpikeSustainDuration = "6m"
    },
    @{
        Name = "Spike Intensity +50%"
        Description = "Increase spike target to 225 users"
        SoakVUs = 40
        LoadMaxTarget = 70
        SpikeMaxTarget = 225
        SpikeRampDuration = "30s"
        SpikeSustainDuration = "6m"
    },
    @{
        Name = "Faster Spike Ramp"
        Description = "Faster ramp to 200 users"
        SoakVUs = 40
        LoadMaxTarget = 70
        SpikeMaxTarget = 200
        SpikeRampDuration = "15s"
        SpikeSustainDuration = "6m"
    },
    @{
        Name = "Extended Spike"
        Description = "Longer spike duration at 180 users"
        SoakVUs = 40
        LoadMaxTarget = 70
        SpikeMaxTarget = 180
        SpikeRampDuration = "30s"
        SpikeSustainDuration = "8m"
    },
    @{
        Name = "High Intensity"
        Description = "300 users spike with fast ramp"
        SoakVUs = 40
        LoadMaxTarget = 70
        SpikeMaxTarget = 300
        SpikeRampDuration = "15s"
        SpikeSustainDuration = "5m"
    },
    @{
        Name = "Extreme Spike"
        Description = "500 users spike - should definitely fail"
        SoakVUs = 40
        LoadMaxTarget = 70
        SpikeMaxTarget = 500
        SpikeRampDuration = "10s"
        SpikeSustainDuration = "4m"
    }
)

function Update-K6Config {
    param(
        [hashtable]$Config
    )
    
    Write-Info "Updating K6 configuration for: $($Config.Name)"
    Write-Host "  Soak VUs: $($Config.SoakVUs)"
    Write-Host "  Load Max Target: $($Config.LoadMaxTarget)"
    Write-Host "  Spike Max Target: $($Config.SpikeMaxTarget)"
    Write-Host "  Spike Ramp Duration: $($Config.SpikeRampDuration)"
    Write-Host "  Spike Sustain Duration: $($Config.SpikeSustainDuration)"
    
    # Create a temporary values file with the new configuration
    $valuesContent = @"
# K6 Test Configuration - Iteration: $($Config.Name)
# $($Config.Description)

# Target application configuration
target:
  service: "reliability-demo.reliability-demo.svc.cluster.local"
  port: 80

# Extended test configuration
tests:
  sequential:
    activeDeadlineSeconds: 7800  # 2 hours 10 minutes timeout
    
    # Resources for tests
    resources:
      requests:
        memory: "1G" 
        cpu: "500m"
      limits:
        memory: "2G"
        cpu: "1"
    
    # Schedule K6 on AMD64 nodes
    nodeSelector:
      kubernetes.io/arch: amd64
      nodepool: default
    
    # Test sequence
    sequence:
      - name: "Soak Test"
        script: "customer-soak-test.js"
        duration: "2h"
        description: "$($Config.SoakVUs) constant users testing GET /api/customers for 2 hours"
      - name: "Load Test"
        script: "customer-load-test.js" 
        duration: "30m"
        description: "Ramping load creating customers (10→30→$($Config.LoadMaxTarget)→50→10 users) for 30 minutes"
      - name: "Spike Test"
        script: "customer-spike-test.js"
        duration: "10m"
        description: "Quick spike to $($Config.SpikeMaxTarget) users then recovery for 10 minutes"

# Test parameters
scripts:
  # Soak test configuration
  soak:
    scenarios:
      vus: $($Config.SoakVUs)
      duration: "2h"
  
  # Load test configuration
  load:
    scenarios:
      stages:
        - duration: "1m"
          target: 10
        - duration: "5m"
          target: 30
        - duration: "10m"
          target: $($Config.LoadMaxTarget)
        - duration: "10m"
          target: 50
        - duration: "4m"
          target: 10
  
  # Spike test configuration
  spike:
    scenarios:
      stages:
        - duration: "1m"
          target: 15
        - duration: "$($Config.SpikeRampDuration)"
          target: $($Config.SpikeMaxTarget)
        - duration: "$($Config.SpikeSustainDuration)"
          target: $($Config.SpikeMaxTarget)
        - duration: "30s"
          target: 15
        - duration: "2m"
          target: 15
"@
    
    # Write to temporary values file
    $valuesFile = "values-iteration-$($Config.Name.Replace(' ', '-')).yaml"
    $valuesContent | Out-File -FilePath "../../helm/k6/$valuesFile" -Encoding UTF8
    
    return $valuesFile
}

function Run-K6Tests {
    param(
        [string]$ValuesFile,
        [hashtable]$Config
    )
    
    Write-Info "Running K6 tests with configuration: $($Config.Name)"
    
    # Change to K6 directory
    Push-Location "../../helm/k6"
    
    try {
        # Clean up previous runs if requested
        if ($CleanupBetweenRuns) {
            Write-Host "  Cleaning up previous test jobs..." -ForegroundColor Yellow
            kubectl delete jobs -n k6 --all 2>$null
            Start-Sleep 10
        }
        
        # Install K6 tests with new configuration
        Write-Host "  Installing K6 tests..." -ForegroundColor Yellow
        ./install.ps1 -ReleaseName "k6-iteration" -Namespace "k6" -ValuesFile $ValuesFile -CleanupFirst
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "  Failed to install K6 tests"
            return $false
        }
        
        # Wait for tests to complete and monitor results
        Write-Host "  Monitoring test execution..." -ForegroundColor Yellow
        $timeout = 300  # 5 minutes timeout for initial startup
        $elapsed = 0
        
        do {
            Start-Sleep 10
            $elapsed += 10
            
            $jobs = kubectl get jobs -n k6 -o json | ConvertFrom-Json
            if ($jobs.items.Count -gt 0) {
                Write-Host "  Tests started, monitoring progress..." -ForegroundColor Green
                break
            }
            
            if ($elapsed -ge $timeout) {
                Write-Error "  Tests did not start within timeout"
                return $false
            }
        } while ($true)
        
        # Monitor test completion (simplified - in practice we'd parse logs for pass/fail)
        Write-Host "  Tests are running. Check logs with:" -ForegroundColor Cyan
        Write-Host "    kubectl logs -n k6 -l k6.test/type=sequential -f" -ForegroundColor White
        Write-Host ""
        Write-Host "  This iteration ($($Config.Name)) is now running..." -ForegroundColor Green
        Write-Host "  Monitor Grafana dashboard for results" -ForegroundColor Cyan
        
        return $true
        
    } finally {
        Pop-Location
    }
}

# Main execution
Write-Info "Starting K6 test iterations..."
Write-Host ""

for ($i = $StartIteration; $i -le $MaxIterations -and $i -le $testConfigurations.Count; $i++) {
    $config = $testConfigurations[$i - 1]
    
    Write-Success "=== Iteration $i/$MaxIterations: $($config.Name) ==="
    Write-Host "Description: $($config.Description)" -ForegroundColor Yellow
    Write-Host ""
    
    # Update K6 configuration
    $valuesFile = Update-K6Config -Config $config
    
    # Run K6 tests
    $success = Run-K6Tests -ValuesFile $valuesFile -Config $config
    
    if (-not $success) {
        Write-Error "Failed to run iteration $i, stopping"
        break
    }
    
    Write-Host ""
    Write-Warning "Iteration $i deployed. Check results in Grafana before continuing to next iteration."
    Write-Host "Press Enter to continue to next iteration, or Ctrl+C to stop..." -ForegroundColor Yellow
    Read-Host
    Write-Host ""
}

Write-Success "K6 iteration testing completed!"
Write-Info "Check Grafana dashboard for detailed results of each iteration"