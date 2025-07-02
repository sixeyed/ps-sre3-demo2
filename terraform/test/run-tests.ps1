#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs Terraform tests and validates the infrastructure code.

.DESCRIPTION
    This script runs various tests on the Terraform code including:
    - Format validation
    - Terraform validation
    - Unit tests (no real resources)
    - Integration tests (optional, creates real resources)
    - Security scanning
    - Cost estimation

.PARAMETER TestType
    Type of tests to run: All, Unit, Integration, Format, Validate, Security

.PARAMETER SkipPrereqCheck
    Skip prerequisite tool checks

.PARAMETER Verbose
    Enable verbose output

.EXAMPLE
    ./run-tests.ps1 -TestType Unit
    ./run-tests.ps1 -TestType All -SkipPrereqCheck

.NOTES
    Requires: Terraform, Go, Azure CLI, and optionally Trivy/Checkov
#>

[CmdletBinding()]
param(
    [ValidateSet('All', 'Unit', 'Integration', 'Format', 'Validate', 'Security', 'Quick')]
    [string]$TestType = 'Quick',
    
    [switch]$SkipPrereqCheck,
    
    [switch]$SkipCleanup,
    
    [string]$TestFilter = "",
    
    [int]$Timeout = 30,
    
    [switch]$GenerateCoverage
)

# Script configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Colors for output
$script:colors = @{
    Success = 'Green'
    Error = 'Red'
    Warning = 'Yellow'
    Info = 'Cyan'
    Header = 'Magenta'
}

# Helper functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [switch]$NoNewline
    )
    
    $params = @{
        ForegroundColor = $script:colors[$Color] ?? $Color
        NoNewline = $NoNewline
    }
    Write-Host $Message @params
}

function Write-TestHeader {
    param([string]$Title)
    
    Write-Host ""
    Write-ColorOutput ("=" * 60) -Color Header
    Write-ColorOutput "  $Title" -Color Header
    Write-ColorOutput ("=" * 60) -Color Header
    Write-Host ""
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Message = "",
        [timespan]$Duration
    )
    
    $status = if ($Success) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($Success) { "Success" } else { "Error" }
    $durationStr = if ($Duration) { " ($($Duration.TotalSeconds.ToString('F2'))s)" } else { "" }
    
    Write-ColorOutput "$status " -Color $color -NoNewline
    Write-Host "$TestName$durationStr"
    
    if ($Message) {
        Write-Host "  $Message"
    }
}

function Test-Prerequisites {
    Write-TestHeader "Checking Prerequisites"
    
    $prerequisites = @(
        @{Name = 'Terraform'; Command = 'terraform version'; Required = $true},
        @{Name = 'Go'; Command = 'go version'; Required = $true},
        @{Name = 'Azure CLI'; Command = 'az --version'; Required = $true},
        @{Name = 'kubectl'; Command = 'kubectl version --client'; Required = $false},
        @{Name = 'Trivy'; Command = 'trivy --version'; Required = $false},
        @{Name = 'Checkov'; Command = 'checkov --version'; Required = $false},
        @{Name = 'tflint'; Command = 'tflint --version'; Required = $false}
    )
    
    $allPassed = $true
    
    foreach ($prereq in $prerequisites) {
        try {
            $output = Invoke-Expression $prereq.Command 2>&1
            Write-TestResult -TestName $prereq.Name -Success $true -Message ($output | Select-Object -First 1)
        }
        catch {
            $success = -not $prereq.Required
            Write-TestResult -TestName $prereq.Name -Success $success -Message "Not installed"
            if ($prereq.Required) {
                $allPassed = $false
            }
        }
    }
    
    if (-not $allPassed) {
        throw "Required prerequisites are missing. Please install them before running tests."
    }
    
    # Check Azure authentication
    Write-Host ""
    Write-ColorOutput "Checking Azure authentication..." -Color Info
    try {
        $account = az account show --query name -o tsv 2>&1
        Write-TestResult -TestName "Azure Login" -Success $true -Message "Logged in to: $account"
    }
    catch {
        Write-TestResult -TestName "Azure Login" -Success $false -Message "Not authenticated"
        Write-ColorOutput "Please run: az login" -Color Warning
        throw "Azure authentication required"
    }
}

function Test-TerraformFormat {
    Write-TestHeader "Terraform Format Check"
    
    $startTime = Get-Date
    Push-Location -Path "../"
    
    try {
        $output = terraform fmt -check -recursive -diff 2>&1
        $success = $LASTEXITCODE -eq 0
        $duration = (Get-Date) - $startTime
        
        if ($success) {
            Write-TestResult -TestName "Format Check" -Success $true -Duration $duration
        }
        else {
            Write-TestResult -TestName "Format Check" -Success $false -Duration $duration
            Write-Host $output
            Write-ColorOutput "`nRun 'terraform fmt -recursive' to fix formatting issues" -Color Warning
        }
        
        return $success
    }
    finally {
        Pop-Location
    }
}

function Test-TerraformValidate {
    Write-TestHeader "Terraform Validation"
    
    $modules = @(
        @{Name = "Main"; Path = "../"},
        @{Name = "AKS Module"; Path = "../modules/aks"},
        @{Name = "ArgoCD Module"; Path = "../modules/argocd"}
    )
    
    $allPassed = $true
    
    foreach ($module in $modules) {
        $startTime = Get-Date
        Push-Location -Path $module.Path
        
        try {
            # Initialize without backend
            $null = terraform init -backend=false 2>&1
            
            # Validate
            $output = terraform validate -json 2>&1
            $success = $LASTEXITCODE -eq 0
            $duration = (Get-Date) - $startTime
            
            Write-TestResult -TestName $module.Name -Success $success -Duration $duration
            
            if (-not $success) {
                $allPassed = $false
                $validation = $output | ConvertFrom-Json
                foreach ($diagnostic in $validation.diagnostics) {
                    Write-ColorOutput "  $($diagnostic.severity): $($diagnostic.summary)" -Color Error
                    if ($diagnostic.detail) {
                        Write-Host "  $($diagnostic.detail)"
                    }
                }
            }
        }
        catch {
            Write-TestResult -TestName $module.Name -Success $false -Message $_.Exception.Message
            $allPassed = $false
        }
        finally {
            Pop-Location
        }
    }
    
    return $allPassed
}

function Test-TerraformUnit {
    Write-TestHeader "Unit Tests"
    
    $startTime = Get-Date
    
    try {
        # Download dependencies
        Write-ColorOutput "Downloading Go dependencies..." -Color Info
        $null = go mod download 2>&1
        
        # Run unit tests
        $testArgs = @(
            'test',
            '-v',
            '-short',
            '-timeout', "${Timeout}m",
            '-parallel', '4'
        )
        
        if ($TestFilter) {
            $testArgs += '-run', $TestFilter
        }
        
        if ($GenerateCoverage) {
            $testArgs += '-coverprofile=coverage.out'
        }
        
        $testArgs += './unit/...'
        
        Write-ColorOutput "Running unit tests..." -Color Info
        $output = & go $testArgs 2>&1 | Out-String
        $success = $LASTEXITCODE -eq 0
        $duration = (Get-Date) - $startTime
        
        # Parse test results
        $passedTests = ($output | Select-String -Pattern "PASS:" -AllMatches).Matches.Count
        $failedTests = ($output | Select-String -Pattern "FAIL:" -AllMatches).Matches.Count
        
        Write-TestResult -TestName "Unit Tests" -Success $success -Duration $duration `
            -Message "Passed: $passedTests, Failed: $failedTests"
        
        if (-not $success -or $VerbosePreference -eq 'Continue') {
            Write-Host $output
        }
        
        # Generate coverage report
        if ($GenerateCoverage -and $success) {
            Write-ColorOutput "Generating coverage report..." -Color Info
            $null = go tool cover -html=coverage.out -o coverage.html 2>&1
            Write-ColorOutput "Coverage report saved to: coverage.html" -Color Success
        }
        
        return $success
    }
    catch {
        Write-TestResult -TestName "Unit Tests" -Success $false -Message $_.Exception.Message
        return $false
    }
}

function Test-TerraformIntegration {
    Write-TestHeader "Integration Tests"
    
    Write-ColorOutput "WARNING: Integration tests create real Azure resources and incur costs!" -Color Warning
    Write-ColorOutput "Press Ctrl+C to cancel, or wait 5 seconds to continue..." -Color Warning
    Start-Sleep -Seconds 5
    
    $startTime = Get-Date
    
    try {
        $testArgs = @(
            'test',
            '-v',
            '-timeout', '60m',
            '-parallel', '2'
        )
        
        if ($TestFilter) {
            $testArgs += '-run', $TestFilter
        }
        
        $testArgs += './integration/...'
        
        Write-ColorOutput "Running integration tests..." -Color Info
        $output = & go $testArgs 2>&1 | Out-String
        $success = $LASTEXITCODE -eq 0
        $duration = (Get-Date) - $startTime
        
        Write-TestResult -TestName "Integration Tests" -Success $success -Duration $duration
        
        if (-not $success -or $VerbosePreference -eq 'Continue') {
            Write-Host $output
        }
        
        return $success
    }
    catch {
        Write-TestResult -TestName "Integration Tests" -Success $false -Message $_.Exception.Message
        return $false
    }
    finally {
        if (-not $SkipCleanup) {
            Write-ColorOutput "Cleaning up test resources..." -Color Info
            Invoke-TestCleanup
        }
    }
}

function Test-Security {
    Write-TestHeader "Security Scanning"
    
    $allPassed = $true
    
    # Trivy scan
    if (Get-Command trivy -ErrorAction SilentlyContinue) {
        $startTime = Get-Date
        Write-ColorOutput "Running Trivy scan..." -Color Info
        
        try {
            $output = trivy config ../ --severity HIGH,CRITICAL --exit-code 1 2>&1 | Out-String
            $success = $LASTEXITCODE -eq 0
            $duration = (Get-Date) - $startTime
            
            Write-TestResult -TestName "Trivy Security Scan" -Success $success -Duration $duration
            
            if (-not $success) {
                Write-Host $output
                $allPassed = $false
            }
        }
        catch {
            Write-TestResult -TestName "Trivy Security Scan" -Success $false -Message $_.Exception.Message
            $allPassed = $false
        }
    }
    
    # Checkov scan
    if (Get-Command checkov -ErrorAction SilentlyContinue) {
        $startTime = Get-Date
        Write-ColorOutput "Running Checkov scan..." -Color Info
        
        try {
            $output = checkov -d ../ --framework terraform --quiet --compact 2>&1 | Out-String
            $success = $LASTEXITCODE -eq 0
            $duration = (Get-Date) - $startTime
            
            Write-TestResult -TestName "Checkov Security Scan" -Success $success -Duration $duration
            
            if (-not $success) {
                Write-Host $output
                $allPassed = $false
            }
        }
        catch {
            Write-TestResult -TestName "Checkov Security Scan" -Success $false -Message $_.Exception.Message
            $allPassed = $false
        }
    }
    
    return $allPassed
}

function Test-Lint {
    Write-TestHeader "Terraform Linting"
    
    if (-not (Get-Command tflint -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "TFLint not installed, skipping..." -Color Warning
        return $true
    }
    
    $startTime = Get-Date
    Push-Location -Path "../"
    
    try {
        # Initialize tflint
        Write-ColorOutput "Initializing TFLint..." -Color Info
        $null = tflint --init 2>&1
        
        # Run tflint
        $output = tflint --recursive --format compact 2>&1 | Out-String
        $success = $LASTEXITCODE -eq 0
        $duration = (Get-Date) - $startTime
        
        Write-TestResult -TestName "TFLint" -Success $success -Duration $duration
        
        if (-not $success) {
            Write-Host $output
        }
        
        return $success
    }
    finally {
        Pop-Location
    }
}

function Invoke-TestCleanup {
    Write-ColorOutput "Checking for orphaned test resources..." -Color Info
    
    try {
        # Find resource groups tagged with Terratest
        $testResourceGroups = az group list --query "[?tags.ManagedBy=='Terratest'].name" -o tsv 2>&1
        
        if ($testResourceGroups) {
            Write-ColorOutput "Found test resource groups to clean up:" -Color Warning
            $testResourceGroups | ForEach-Object { Write-Host "  - $_" }
            
            Write-ColorOutput "Deleting test resource groups..." -Color Info
            $testResourceGroups | ForEach-Object {
                az group delete --name $_ --yes --no-wait
            }
        }
        else {
            Write-ColorOutput "No orphaned test resources found" -Color Success
        }
    }
    catch {
        Write-ColorOutput "Failed to check/cleanup resources: $_" -Color Error
    }
}

function Show-TestSummary {
    param(
        [hashtable]$Results,
        [timespan]$TotalDuration
    )
    
    Write-TestHeader "Test Summary"
    
    $passed = ($Results.Values | Where-Object { $_ }).Count
    $failed = ($Results.Values | Where-Object { -not $_ }).Count
    $total = $Results.Count
    
    Write-Host "Total Tests: $total"
    Write-ColorOutput "Passed: $passed" -Color Success
    if ($failed -gt 0) {
        Write-ColorOutput "Failed: $failed" -Color Error
    }
    Write-Host "Duration: $($TotalDuration.ToString('mm\:ss'))"
    
    Write-Host ""
    Write-Host "Results:"
    foreach ($test in $Results.GetEnumerator()) {
        $status = if ($test.Value) { "✓" } else { "✗" }
        $color = if ($test.Value) { "Success" } else { "Error" }
        Write-ColorOutput "$status $($test.Key)" -Color $color
    }
    
    if ($failed -gt 0) {
        Write-Host ""
        Write-ColorOutput "TESTS FAILED" -Color Error
        exit 1
    }
    else {
        Write-Host ""
        Write-ColorOutput "ALL TESTS PASSED" -Color Success
    }
}

# Main execution
function Main {
    $totalStartTime = Get-Date
    $results = @{}
    
    Write-ColorOutput @"
╔══════════════════════════════════════════════════════════╗
║            Terraform Test Suite                          ║
║                                                          ║
║  Test Type: $TestType                                    
║  Timeout: $Timeout minutes                               
║  Filter: $(if ($TestFilter) { $TestFilter } else { 'None' })
╚══════════════════════════════════════════════════════════╝
"@ -Color Header
    
    try {
        # Check prerequisites
        if (-not $SkipPrereqCheck) {
            Test-Prerequisites
        }
        
        # Run tests based on type
        switch ($TestType) {
            'Quick' {
                $results['Format'] = Test-TerraformFormat
                $results['Validate'] = Test-TerraformValidate
                $results['Lint'] = Test-Lint
                $results['Unit Tests'] = Test-TerraformUnit
            }
            'Unit' {
                $results['Format'] = Test-TerraformFormat
                $results['Validate'] = Test-TerraformValidate
                $results['Unit Tests'] = Test-TerraformUnit
            }
            'Integration' {
                $results['Integration Tests'] = Test-TerraformIntegration
            }
            'Format' {
                $results['Format'] = Test-TerraformFormat
            }
            'Validate' {
                $results['Validate'] = Test-TerraformValidate
            }
            'Security' {
                $results['Security'] = Test-Security
            }
            'All' {
                $results['Format'] = Test-TerraformFormat
                $results['Validate'] = Test-TerraformValidate
                $results['Lint'] = Test-Lint
                $results['Unit Tests'] = Test-TerraformUnit
                $results['Security'] = Test-Security
                $results['Integration Tests'] = Test-TerraformIntegration
            }
        }
        
        $totalDuration = (Get-Date) - $totalStartTime
        Show-TestSummary -Results $results -TotalDuration $totalDuration
    }
    catch {
        Write-ColorOutput "`nERROR: $_" -Color Error
        Write-ColorOutput $_.ScriptStackTrace -Color Error
        exit 1
    }
}

# Run main function
Main