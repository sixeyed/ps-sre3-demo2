# Makefile for running Terraform tests

.PHONY: all test unit integration fmt lint clean help

# Default target
all: fmt lint test

# Run all tests
test: unit integration

# Run unit tests only (fast, no real resources)
unit:
	@echo "Running unit tests..."
	cd $(PWD) && go test -v -short -timeout 30m ./unit/...

# Run integration tests (creates real Azure resources)
integration:
	@echo "Running integration tests (this will create real resources)..."
	@echo "Press Ctrl+C to cancel in the next 5 seconds..."
	@sleep 5
	cd $(PWD) && go test -v -timeout 60m ./integration/...

# Run a specific test
test-specific:
	@echo "Running test: $(TEST)"
	cd $(PWD) && go test -v -run $(TEST) ./...

# Format Go code
fmt:
	@echo "Formatting Go code..."
	go fmt ./...

# Lint Go code
lint:
	@echo "Linting Go code..."
	golangci-lint run ./...

# Run tests with coverage
coverage:
	@echo "Running tests with coverage..."
	go test -v -short -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	rm -f coverage.out coverage.html
	rm -f terraform.tfplan terraform.tfstate*
	find . -name ".terraform" -type d -exec rm -rf {} +
	find . -name "*.tfplan" -exec rm -f {} +

# Install test dependencies
deps:
	@echo "Installing test dependencies..."
	go mod download
	go mod tidy

# Validate Terraform files
validate:
	@echo "Validating Terraform files..."
	cd ../../ && terraform fmt -check -recursive
	cd ../../ && terraform validate

# Run security scans
security:
	@echo "Running security scans..."
	trivy config ../../
	checkov -d ../../ --framework terraform

# Help
help:
	@echo "Available targets:"
	@echo "  make test          - Run all tests"
	@echo "  make unit          - Run unit tests only (fast)"
	@echo "  make integration   - Run integration tests (creates resources)"
	@echo "  make test-specific TEST=TestName - Run specific test"
	@echo "  make coverage      - Run tests with coverage report"
	@echo "  make fmt           - Format Go code"
	@echo "  make lint          - Lint Go code"
	@echo "  make clean         - Clean test artifacts"
	@echo "  make deps          - Install dependencies"
	@echo "  make validate      - Validate Terraform files"
	@echo "  make security      - Run security scans"
	@echo "  make help          - Show this help"

# Environment setup
.EXPORT_ALL_VARIABLES:
TF_IN_AUTOMATION = true
ARM_SKIP_PROVIDER_REGISTRATION = true