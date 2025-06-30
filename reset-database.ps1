#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Resets the customer database by truncating the Customers table
.DESCRIPTION
    This script connects to the SQL Server pod in Kubernetes and truncates the Customers table
    to reset the data between demo runs without needing to restart SQL Server.
.PARAMETER Namespace
    The Kubernetes namespace where the SQL Server pod is running (default: default)
.PARAMETER ReleaseName
    The Helm release name for the deployment (default: reliability-demo)
.EXAMPLE
    ./reset-database.ps1
.EXAMPLE
    ./reset-database.ps1 -Namespace demo -ReleaseName my-demo
#>

param(
    [string]$ReleaseName = "reliability-demo",
    [string]$Namespace = "sre3-m1"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🔄 Resetting customer database..." -ForegroundColor Yellow

try {
    # Get the SQL Server pod name
    $podName = kubectl get pods -n $Namespace -l "app.kubernetes.io/component=sqlserver,app.kubernetes.io/name=$ReleaseName" -o jsonpath="{.items[0].metadata.name}" 2>$null
    
    if (-not $podName) {
        Write-Error "❌ Could not find SQL Server pod for release '$ReleaseName' in namespace '$Namespace'"
        exit 1
    }
    
    Write-Host "📍 Found SQL Server pod: $podName" -ForegroundColor Green
    
    # SQL command to truncate the Customers table
    $sqlCommand = @"
USE ReliabilityDemo;
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Customers')
BEGIN
    TRUNCATE TABLE Customers;
    PRINT 'Customers table truncated successfully';
END
ELSE
BEGIN
    PRINT 'Customers table does not exist yet';
END
"@
    
    Write-Host "🗃️  Truncating Customers table..." -ForegroundColor Blue
    
    # Execute the SQL command via kubectl exec
    $result = kubectl exec -n $Namespace $podName -- /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStrong@Passw0rd' -C -Q $sqlCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database reset completed successfully!" -ForegroundColor Green
        Write-Host "📊 Customer data cleared - ready for next demo run" -ForegroundColor Cyan
    } else {
        Write-Error "❌ Failed to reset database. Exit code: $LASTEXITCODE"
        Write-Host "Output: $result" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Error "❌ Error resetting database: $($_.Exception.Message)"
    exit 1
}

Write-Host ""
Write-Host "💡 You can now run your load tests with a clean database!" -ForegroundColor Yellow