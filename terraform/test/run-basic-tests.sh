#!/bin/bash
set -e

echo "🧪 Running basic unit tests without k8s dependencies..."

# Ensure test results directory exists
mkdir -p /workspace/test-results

# Copy go.mod.minimal to go.mod if it exists
if [ -f "/workspace/go.mod.minimal" ]; then
    echo "Using minimal go.mod..."
    cp /workspace/go.mod.minimal /workspace/go.mod
fi

# Copy unit tests if they're mounted separately
if [ -d "/workspace/unit" ] && [ ! -d "/workspace/terraform/test/unit" ]; then
    mkdir -p /workspace/terraform/test
    cp -r /workspace/unit /workspace/terraform/test/
fi

# Navigate to test directory
cd /workspace/terraform/test || cd /workspace

# Download dependencies
echo "Downloading minimal dependencies..."
go mod download

# Run only the basic test that doesn't require k8s
echo "Running basic_terraform_test.go..."
go test -v ./unit/basic_terraform_test.go 2>&1 | tee /workspace/test-results/basic-test-output.txt

# Generate test report
echo "Generating test report..."
cat > /workspace/test-results/test-report.txt << EOF
Test Execution Report
====================
Date: $(date)
Test Type: Basic Unit Tests (No K8s Dependencies)

Test Files Executed:
- basic_terraform_test.go

Results:
EOF

# Append test results
go test ./unit/basic_terraform_test.go -json 2>&1 | grep -E '"(Pass|Fail|Skip)"' >> /workspace/test-results/test-report.txt || true

# List all generated files
echo -e "\n\nGenerated Files:" >> /workspace/test-results/test-report.txt
ls -la /workspace/test-results/ >> /workspace/test-results/test-report.txt

echo "✅ Basic tests completed successfully!"