# Module 3 Demo 1 - K6 Load Testing
# This script deploys K6 load tests with Azure-specific configuration

param(
    [switch]$Force,
    [string]$TestType = "sequential",  # sequential, soak, load, spike
    [string]$Namespace = "reliability-demo"
)

Write-Host "Module 3 Demo 1 - K6 Load Testing" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Check prerequisites
Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow

# Check kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: kubectl is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check helm
if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: helm is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check if connected to cluster
try {
    $clusterInfo = kubectl cluster-info --request-timeout=5s 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Not connected to Kubernetes cluster" -ForegroundColor Red
        Write-Host "Run: az aks get-credentials --resource-group reliability-demo-production --name aks-reliability-demo-production" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✓ Connected to Kubernetes cluster" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Cannot connect to Kubernetes cluster" -ForegroundColor Red
    exit 1
}

# Check if target application is running
Write-Host "`nChecking target application..." -ForegroundColor Yellow
try {
    $appStatus = kubectl get deployment reliability-demo -n $Namespace -o jsonpath='{.status.readyReplicas}' 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($appStatus) -or $appStatus -eq "0") {
        Write-Host "ERROR: Reliability demo application is not running in namespace '$Namespace'" -ForegroundColor Red
        Write-Host "Run the setup script first to deploy the application" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✓ Application is running with $appStatus ready replicas" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Cannot check application status" -ForegroundColor Red
    exit 1
}

# Configuration
$releaseName = "k6-tests"
$chartPath = "../../helm/k6"
$baseValuesFile = "../../helm/k6/values.yaml"
$azureValuesFile = "../../helm/k6/values-azure.yaml"

Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  Release Name: $releaseName"
Write-Host "  Test Type: $TestType"
Write-Host "  Namespace: $Namespace"
Write-Host "  Chart Path: $chartPath"
Write-Host "  Base Values: $baseValuesFile"
Write-Host "  Azure Values: $azureValuesFile"

# Validate test type
$validTestTypes = @("sequential", "soak", "load", "spike")
if ($TestType -notin $validTestTypes) {
    Write-Host "`nERROR: Invalid test type '$TestType'" -ForegroundColor Red
    Write-Host "Valid options: $($validTestTypes -join ', ')" -ForegroundColor Yellow
    exit 1
}

# Check for existing release
Write-Host "`nChecking for existing K6 tests..." -ForegroundColor Yellow
$existingRelease = helm list -n $Namespace --filter $releaseName --short 2>$null
if (-not [string]::IsNullOrEmpty($existingRelease)) {
    if (-not $Force) {
        Write-Host "WARNING: K6 test release '$releaseName' already exists" -ForegroundColor Yellow
        $confirm = Read-Host "Remove existing release and deploy new tests? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "`nK6 test deployment cancelled" -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host "Removing existing K6 test release..." -ForegroundColor Yellow
    helm uninstall $releaseName -n $Namespace
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to remove existing release" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Existing release removed" -ForegroundColor Green
}

# Deploy K6 tests
Write-Host "`nDeploying K6 load tests..." -ForegroundColor Cyan

try {
    # Build helm command based on test type
    if ($TestType -eq "sequential") {
        # Deploy sequential tests (default)
        helm install $releaseName $chartPath `
            --namespace $Namespace `
            --values $baseValuesFile `
            --values $azureValuesFile `
            --wait `
            --timeout 10m
    } else {
        # Deploy individual test
        helm install $releaseName $chartPath `
            --namespace $Namespace `
            --values $baseValuesFile `
            --values $azureValuesFile `
            --set tests.sequential.enabled=false `
            --set tests.individual.enabled=true `
            --set tests.individual.testType=$TestType `
            --wait `
            --timeout 10m
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ K6 tests deployed successfully!" -ForegroundColor Green
        
        # Show test status
        Write-Host "`nTest Job Status:" -ForegroundColor Cyan
        kubectl get jobs -n $Namespace -l app.kubernetes.io/name=k6 -o wide
        
        Write-Host "`nTest Pods:" -ForegroundColor Cyan
        kubectl get pods -n $Namespace -l app.kubernetes.io/name=k6 -o wide
        
        Write-Host "`nTo monitor test progress:" -ForegroundColor Yellow
        Write-Host "kubectl logs -n $Namespace -l app.kubernetes.io/name=k6 -f" -ForegroundColor White
        
        Write-Host "`nTo view test results:" -ForegroundColor Yellow
        Write-Host "kubectl logs -n $Namespace -l app.kubernetes.io/name=k6" -ForegroundColor White
        
        Write-Host "`nTo clean up after tests complete:" -ForegroundColor Yellow
        Write-Host "helm uninstall $releaseName -n $Namespace" -ForegroundColor White
        
        if ($TestType -eq "sequential") {
            Write-Host "`nAzure Demo Test Schedule:" -ForegroundColor Cyan
            Write-Host "  1. Soak Test: 2 hours with 40 constant users"
            Write-Host "  2. Load Test: 30 minutes with ramping load (10→30→70→50→10)"
            Write-Host "  3. Spike Test: 10 minutes with spike to 150 users"
            Write-Host "  Total Duration: ~2 hours 40 minutes"
        }
        
    } else {
        Write-Host "ERROR: Failed to deploy K6 tests" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "ERROR: Failed to deploy K6 tests" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "`nK6 load testing started!" -ForegroundColor Green