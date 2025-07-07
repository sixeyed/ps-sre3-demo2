# install-tools-macos.ps1 - Install required tools for Demo 2
# Prerequisites: PowerShell 7+ (install with: brew install --cask powershell)

param(
    [switch]$SkipHomebrew,
    [switch]$Verify
)

# Color output functions
function Write-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Warning { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host $Message -ForegroundColor Red }

# Header
Write-Success "=============================================="
Write-Success "Demo 2 GitOps - Tool Installation"
Write-Success "=============================================="

# Check if Homebrew is installed
if (-not $SkipHomebrew) {
    Write-Info "`nChecking Homebrew installation..."
    
    try {
        $brewVersion = brew --version 2>$null
        Write-Success "✓ Homebrew is already installed"
    } catch {
        Write-Info "Installing Homebrew..."
        $installScript = '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        Invoke-Expression $installScript
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Homebrew installed successfully"
        } else {
            Write-Error "✗ Homebrew installation failed"
            exit 1
        }
    }
}

# Core tools installation for Demo 2
Write-Info "`nInstalling tools needed for Demo 2..."

$demoTools = @(
    @{ name = "terraform"; formula = "hashicorp/tap/terraform"; tap = "hashicorp/tap" },
    @{ name = "kubectl"; formula = "kubectl" },
    @{ name = "azure-cli"; formula = "azure-cli"; alias = "az" },
    @{ name = "git"; formula = "git" }
)

foreach ($tool in $demoTools) {
    Write-Info "Installing $($tool.name)..."
    
    # Add tap if specified
    if ($tool.tap) {
        brew tap $tool.tap 2>$null
    }
    
    # Install the tool
    brew install $tool.formula
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ $($tool.name) installed"
    } else {
        Write-Warning "⚠ $($tool.name) installation may have failed or was already installed"
    }
}

# Verification
if ($Verify -or -not $PSBoundParameters.ContainsKey('Verify')) {
    Write-Info "`nVerifying installations..."
    
    $verifications = @(
        @{ name = "PowerShell"; command = { $PSVersionTable.PSVersion.ToString() }; expectedPattern = "^7\." },
        @{ name = "Terraform"; command = { terraform --version }; expectedPattern = "Terraform v" },
        @{ name = "kubectl"; command = { kubectl version --client --output=yaml 2>$null }; expectedPattern = "gitVersion" },
        @{ name = "Azure CLI"; command = { az --version }; expectedPattern = "azure-cli" },
        @{ name = "Git"; command = { git --version }; expectedPattern = "git version" }
    )
    
    $allSuccess = $true
    
    foreach ($verification in $verifications) {
        try {
            $output = & $verification.command
            if ($output -match $verification.expectedPattern) {
                Write-Success "✓ $($verification.name): Working"
            } else {
                Write-Warning "⚠ $($verification.name): Unexpected output"
                $allSuccess = $false
            }
        } catch {
            Write-Error "✗ $($verification.name): Not found or not working"
            $allSuccess = $false
        }
    }
    
    if ($allSuccess) {
        Write-Success "`n🎉 All tools installed and verified successfully!"
    } else {
        Write-Warning "`n⚠ Some tools may need manual verification or installation"
    }
}

# Next steps
Write-Info "`nNext Steps:"
Write-Host "1. Configure Azure authentication:" -ForegroundColor Gray
Write-Host "   az login" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Ensure GitHub repository has secrets configured:" -ForegroundColor Gray
Write-Host "   - AZURE_CLIENT_ID" -ForegroundColor Gray
Write-Host "   - AZURE_CLIENT_SECRET" -ForegroundColor Gray
Write-Host "   - AZURE_SUBSCRIPTION_ID" -ForegroundColor Gray
Write-Host "   - AZURE_TENANT_ID" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Validate Terraform configuration:" -ForegroundColor Gray
Write-Host "   cd ../../terraform" -ForegroundColor Gray
Write-Host "   terraform init" -ForegroundColor Gray
Write-Host "   terraform validate" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Ready to record Demo 2!" -ForegroundColor Gray

Write-Success "`nDemo 2 tool installation complete! 🚀"