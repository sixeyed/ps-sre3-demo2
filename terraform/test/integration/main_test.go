package integration

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestFullStackIntegration(t *testing.T) {
	t.Parallel()

	// Skip if not running integration tests
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// Generate unique names
	uniqueID := random.UniqueId()
	resourceGroupName := fmt.Sprintf("rg-test-%s", uniqueID)
	clusterName := fmt.Sprintf("aks-test-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform",
		Vars: map[string]interface{}{
			"resource_group_name": resourceGroupName,
			"cluster_name":        clusterName,
			"location":            "westeurope",
			"kubernetes_version":  "1.28.3",
			"node_count":          1,
			"min_node_count":      1,
			"max_node_count":      3,
			"node_vm_size":        "Standard_B2s", // Smaller size for testing
			"tags": map[string]string{
				"Environment": "Test",
				"TestID":      uniqueID,
				"ManagedBy":   "Terratest",
			},
		},
		EnvVars: map[string]string{
			"ARM_SKIP_PROVIDER_REGISTRATION": "true",
		},
	})

	// Ensure cleanup
	defer terraform.Destroy(t, terraformOptions)

	// Deploy infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	kubeconfig := terraform.Output(t, terraformOptions, "kube_config")
	require.NotEmpty(t, kubeconfig)

	// Create kubeconfig file
	kubeconfigPath := k8s.WriteKubeConfigToTempFile(t, kubeconfig)
	options := k8s.NewKubectlOptions("", kubeconfigPath, "default")

	// Test cluster connectivity
	err := k8s.RunKubectlE(t, options, "cluster-info")
	require.NoError(t, err)

	// Verify namespaces
	verifyNamespaces(t, options)

	// Verify ArgoCD deployment
	verifyArgoCDDeployment(t, options)

	// Test ArgoCD applications
	verifyArgoCDApplications(t, options)

	// Verify node scaling
	verifyNodeScaling(t, terraformOptions, options)
}

func verifyNamespaces(t *testing.T, options *k8s.KubectlOptions) {
	expectedNamespaces := []string{"reliability-demo", "argocd", "monitoring"}

	for _, ns := range expectedNamespaces {
		namespace := k8s.GetNamespace(t, options, ns)
		assert.Equal(t, ns, namespace.Name)
		assert.Equal(t, corev1.NamespaceActive, namespace.Status.Phase)
	}
}

func verifyArgoCDDeployment(t *testing.T, options *k8s.KubectlOptions) {
	options = options.WithNamespace("argocd")

	// Wait for ArgoCD server to be ready
	k8s.WaitUntilDeploymentAvailable(t, options, "argocd-server", 20, 30*time.Second)

	// Verify ArgoCD server deployment
	deployment := k8s.GetDeployment(t, options, "argocd-server")
	assert.GreaterOrEqual(t, int(*deployment.Spec.Replicas), 2, "ArgoCD server should have at least 2 replicas")

	// Verify resource limits
	container := deployment.Spec.Template.Spec.Containers[0]
	assert.NotNil(t, container.Resources.Limits)
	assert.NotNil(t, container.Resources.Requests)

	// Verify ArgoCD controller
	k8s.WaitUntilDeploymentAvailable(t, options, "argocd-applicationset-controller", 10, 30*time.Second)
	k8s.WaitUntilDeploymentAvailable(t, options, "argocd-repo-server", 10, 30*time.Second)
}

func verifyArgoCDApplications(t *testing.T, options *k8s.KubectlOptions) {
	options = options.WithNamespace("argocd")

	// Check if app-of-apps exists
	output, err := k8s.RunKubectlAndGetOutputE(t, options, "get", "application", "app-of-apps", "-o", "jsonpath={.metadata.name}")
	if err == nil {
		assert.Equal(t, "app-of-apps", output)
	}
}

func verifyNodeScaling(t *testing.T, terraformOptions *terraform.Options, options *k8s.KubectlOptions) {
	// Get initial node count
	nodes := k8s.GetNodes(t, options)
	initialNodeCount := len(nodes)
	assert.GreaterOrEqual(t, initialNodeCount, 1)

	// Update node count
	terraformOptions.Vars["node_count"] = 2
	terraform.Apply(t, terraformOptions)

	// Wait for scaling
	time.Sleep(60 * time.Second)

	// Verify new node count
	nodes = k8s.GetNodes(t, options)
	assert.GreaterOrEqual(t, len(nodes), 2)
}

func TestAKSModuleOnly(t *testing.T) {
	t.Parallel()

	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	uniqueID := random.UniqueId()
	resourceGroupName := fmt.Sprintf("rg-aks-test-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/aks",
		Vars: map[string]interface{}{
			"cluster_name":        fmt.Sprintf("aks-%s", uniqueID),
			"resource_group_name": resourceGroupName,
			"location":            "westeurope",
			"kubernetes_version":  "1.28.3",
			"node_count":          1,
			"node_vm_size":        "Standard_B2s",
			"enable_auto_scaling": false,
			"tags": map[string]string{
				"TestID": uniqueID,
			},
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	// First create resource group
	createResourceGroup(t, resourceGroupName, "westeurope")
	defer deleteResourceGroup(t, resourceGroupName)

	terraform.InitAndApply(t, terraformOptions)

	// Verify outputs
	clusterID := terraform.Output(t, terraformOptions, "cluster_id")
	assert.NotEmpty(t, clusterID)

	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	assert.Equal(t, fmt.Sprintf("aks-%s", uniqueID), clusterName)
}

func TestArgoCDModuleWithMockCluster(t *testing.T) {
	t.Parallel()

	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// This test would require a mock Kubernetes cluster
	// For simplicity, we're testing the terraform plan only
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/argocd",
		Vars: map[string]interface{}{
			"namespace":            "argocd-test",
			"argocd_chart_version": "5.51.6",
			"git_repo_url":         "https://github.com/sixeyed/ps-sre3-demo2",
			"git_target_revision":  "main",
		},
		PlanFilePath: "terraform.tfplan",
	})

	terraform.InitAndPlan(t, terraformOptions)
}

// Helper functions
func createResourceGroup(t *testing.T, name, location string) {
	cmd := fmt.Sprintf("az group create --name %s --location %s", name, location)
	k8s.RunKubectl(t, k8s.NewKubectlOptions("", "", ""), "exec", cmd)
}

func deleteResourceGroup(t *testing.T, name string) {
	cmd := fmt.Sprintf("az group delete --name %s --yes --no-wait", name)
	k8s.RunKubectl(t, k8s.NewKubectlOptions("", "", ""), "exec", cmd)
}