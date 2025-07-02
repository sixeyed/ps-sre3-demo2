#!/bin/bash
set -e

echo "🔧 Tool Versions:"
echo "Go: $(go version)"
echo "Terraform: $(terraform version | head -1)"
echo "Azure CLI: $(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo 'Available')"
echo "kubectl: $(kubectl version --client=true --short 2>/dev/null || echo 'Available')"
echo "Helm: $(helm version --short 2>/dev/null || echo 'Available')"

TEST_TYPE=${1:-Quick}
echo ""
echo "🧪 Running $TEST_TYPE tests..."

# Copy terraform source to writable location if needed
if [ -d "/workspace/terraform-src" ] && [ ! -d "/workspace/terraform" ]; then
    echo "Copying terraform source to writable location..."
    cp -r /workspace/terraform-src /workspace/terraform
    chmod -R 755 /workspace/terraform
fi

# Navigate to terraform directory
if [ -d "/workspace/terraform" ]; then
    cd /workspace/terraform
elif [ -d "/workspace" ]; then
    cd /workspace
else
    echo "❌ No terraform directory found"
    exit 1
fi

case $TEST_TYPE in
    "Format"|"format")
        echo "🎨 Checking Terraform format..."
        terraform fmt -check -recursive -diff
        ;;
    
    "Validate"|"validate")
        echo "🔍 Validating Terraform..."
        terraform init -backend=false
        terraform validate
        
        # Validate modules
        for module in modules/*/; do
            if [ -d "$module" ]; then
                echo "Validating $(basename "$module")..."
                cd "$module"
                terraform init -backend=false
                terraform validate
                cd - >/dev/null
            fi
        done
        ;;
    
    "Unit"|"unit")
        echo "🧪 Running Go unit tests..."
        # Use dedicated unit test script
        exec /run-unit-tests.sh
        ;;
    
    "Security"|"security")
        echo "🔒 Running security scans..."
        echo "Note: Security tools not installed in this image, running validation instead"
        terraform fmt -check -recursive
        terraform init -backend=false
        terraform validate
        ;;
    
    "Quick"|*)
        echo "🚀 Running quick validation..."
        terraform fmt -check -recursive
        terraform init -backend=false
        terraform validate
        
        # Quick module check
        for module in modules/*/; do
            if [ -d "$module" ]; then
                echo "✓ $(basename "$module")"
                cd "$module"
                terraform init -backend=false >/dev/null 2>&1
                terraform validate >/dev/null 2>&1
                cd - >/dev/null
            fi
        done
        ;;
esac

echo "✅ Tests completed successfully!"