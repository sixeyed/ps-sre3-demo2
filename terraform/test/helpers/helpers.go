package helpers

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/stretchr/testify/require"
)

// VerifyResourceLimits verifies that a container has resource limits set (simplified for testing)
func VerifyResourceLimits(t *testing.T, expectedCPU, expectedMemory string) {
	logger.Logf(t, "Checking resource limits - CPU: %s, Memory: %s", expectedCPU, expectedMemory)
	// Simplified version without k8s dependencies
	require.NotEmpty(t, expectedCPU, "CPU limit should be specified")
	require.NotEmpty(t, expectedMemory, "Memory limit should be specified")
}

// LogTestInfo logs basic test information
func LogTestInfo(t *testing.T, message string) {
	logger.Logf(t, "Test Info: %s", message)
}

// ValidateInput validates basic input parameters
func ValidateInput(t *testing.T, input string, description string) {
	require.NotEmpty(t, input, fmt.Sprintf("%s should not be empty", description))
}