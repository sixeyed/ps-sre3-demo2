#!/bin/bash

# Demo Script for Manual Deployment Anti-Patterns
# This script simulates the manual deployment process with all its issues

echo "=== Module 2 Demo 1: Manual Deployment Anti-Patterns ==="
echo ""

# Function to pause and wait for Enter
pause() {
    echo ""
    read -p "Press Enter to continue..."
    echo ""
}

# Step 0: Deploy working version first
echo "Step 0: First deploying the working version of the application..."
echo "kubectl apply -f manifests/initial/"
echo ""
echo "namespace/reliability-demo created"
echo "deployment.apps/sqlserver created"
echo "service/sqlserver created"
echo "deployment.apps/redis created"
echo "service/redis created"
echo "configmap/reliability-demo-config created"
echo "deployment.apps/reliability-demo-web created"
echo "service/reliability-demo-web created"
echo "deployment.apps/reliability-demo-worker created"
echo ""
echo "Application is now running correctly..."
pause

# Step 1: Show test cluster
echo "Step 1: Checking test cluster status..."
echo "kubectl get nodes"
echo ""
echo "NAME               STATUS   ROLES    AGE    VERSION"
echo "test-worker-1      Ready    <none>   142d   v1.24.2"
echo "test-worker-2      Ready    <none>   142d   v1.24.2"
echo "test-worker-3      Ready    <none>   142d   v1.24.2"
pause

# Step 2: Show current deployments
echo "Step 2: Checking current deployments..."
echo "kubectl get deployments -n reliability-demo"
echo ""
echo "NAME                      READY   UP-TO-DATE   AVAILABLE   AGE"
echo "redis                     1/1     1            1           2m"
echo "reliability-demo-web      3/3     3            3           2m"
echo "reliability-demo-worker   2/2     2            2           2m"
echo "sqlserver                 1/1     1            1           2m"
pause

# Step 3: Show manifest versions confusion
echo "Step 3: Development team wants to update - checking their manifests..."
echo "ls -la manifests/"
echo ""
echo "total 40"
echo "drwxr-xr-x  8 dev  staff   256 Jan 15 14:30 ."
echo "drwxr-xr-x  4 dev  staff   128 Jan 15 14:00 .."
echo "drwxr-xr-x  7 sre  staff   224 Jan 15 08:00 initial/"
echo "-rw-r--r--  1 dev  staff   892 Jan 14 12:00 customer-api-v1.yaml"
echo "-rw-r--r--  1 dev  staff  1243 Jan 14 16:30 customer-api-v2.yaml"
echo "-rw-r--r--  1 dev  staff  1567 Jan 15 09:00 customer-api-final.yaml"
echo "-rw-r--r--  1 bob  staff   289 Jan 15 10:00 customer-api-config.yaml"
echo ""
echo "Note: Multiple versions from different team members, unclear which is current"
pause

# Step 4: Dev team creates their broken config
echo "Step 4: Dev team creating their own ConfigMap..."
echo "kubectl apply -f manifests/customer-api-config.yaml"
echo "configmap/reliability-demo-config-broken created"
pause

# Step 5: Deploy with timestamp version
echo "Step 5: Dev team deploying their 'latest' version..."
echo "kubectl apply -f manifests/customer-api-final.yaml"
echo "deployment.apps/reliability-demo-web configured"
echo "service/reliability-demo-web unchanged"
pause

# Step 6: Check pod status - resource issues
echo "Step 6: Checking deployment status..."
echo "kubectl get pods -n reliability-demo"
echo ""
echo "NAME                                       READY   STATUS    RESTARTS   AGE"
echo "redis-7b8d9f8c5-xkq2m                     1/1     Running   0          5m"
echo "sqlserver-5c9d8f7b6-plm3n                 1/1     Running   0          5m"
echo "reliability-demo-worker-8f7d6c5b4-jk8mn   1/1     Running   0          5m"
echo "reliability-demo-worker-8f7d6c5b4-qw9rt   1/1     Running   0          5m"
echo "reliability-demo-web-6d5b7c8f9-2xnkl     0/1     Pending   0          20s"
echo "reliability-demo-web-6d5b7c8f9-8m3pq     0/1     Pending   0          20s"
echo "reliability-demo-web-6d5b7c8f9-kl9mn     0/1     Pending   0          20s"
echo "reliability-demo-web-6d5b7c8f9-qw4rt     0/1     Pending   0          20s"
echo "reliability-demo-web-6d5b7c8f9-zx8cv     0/1     Pending   0          20s"
echo ""
echo "ERROR: New pods stuck in Pending state!"
pause

# Step 7: Show resource issue
echo "Step 7: Investigating resource issues..."
echo "kubectl describe pod reliability-demo-web-6d5b7c8f9-2xnkl -n reliability-demo | tail -20"
echo ""
echo "Events:"
echo "  Type     Reason            Age   From               Message"
echo "  ----     ------            ----  ----               -------"
echo "  Warning  FailedScheduling  45s   default-scheduler  0/3 nodes are available:"
echo "                                                      3 Insufficient memory."
echo ""
echo "Note: Production resource requests (2Gi) too high for test cluster"
pause

# Step 8: Fix by editing manifest
echo "Step 8: Manually editing manifest to reduce resources..."
echo "vi manifests/customer-api-final.yaml"
echo "(Reducing memory from 2Gi to 512Mi)"
echo ""
echo "kubectl apply -f manifests/customer-api-final.yaml"
echo "deployment.apps/reliability-demo-web configured"
pause

# Step 9: Pods running but app broken
echo "Step 9: Checking pods after resource fix..."
echo "kubectl get pods -n reliability-demo"
echo ""
echo "NAME                                       READY   STATUS    RESTARTS   AGE"
echo "redis-7b8d9f8c5-xkq2m                     1/1     Running   0          8m"
echo "sqlserver-5c9d8f7b6-plm3n                 1/1     Running   0          8m"
echo "reliability-demo-worker-8f7d6c5b4-jk8mn   1/1     Running   0          8m"
echo "reliability-demo-worker-8f7d6c5b4-qw9rt   1/1     Running   0          8m"
echo "reliability-demo-web-6d5b7c8f9-abc12     1/1     Running   0          30s"
echo "reliability-demo-web-6d5b7c8f9-def34     1/1     Running   0          30s"
echo "reliability-demo-web-6d5b7c8f9-ghi56     1/1     Running   0          30s"
echo "reliability-demo-web-6d5b7c8f9-jkl78     1/1     Running   0          30s"
echo "reliability-demo-web-6d5b7c8f9-mno90     1/1     Running   0          30s"
pause

# Step 10: Check logs - connection error
echo "Step 10: Application not working, checking logs..."
echo "kubectl logs deployment/reliability-demo-web -n reliability-demo | tail -10"
echo ""
echo "[ERROR] Failed to connect to Redis"
echo "[ERROR] Connection refused: localhost:6379"
echo "[ERROR] Failed to connect to SQL Server"
echo "[ERROR] Connection refused: localhost:1433"
echo "[ERROR] Retrying connections..."
echo ""
echo "Note: ConfigMap has wrong connection strings (localhost instead of service names)"
pause

# Step 11: Fix ConfigMap
echo "Step 11: Fixing connection strings in ConfigMap..."
echo "kubectl edit configmap reliability-demo-config-broken -n reliability-demo"
echo "(Changing localhost to redis and sqlserver)"
echo ""
echo "configmap/reliability-demo-config-broken edited"
echo ""
echo "kubectl rollout restart deployment reliability-demo-web -n reliability-demo"
echo "deployment.apps/reliability-demo-web restarted"
pause

# Step 12: Try to scale - cluster limitations
echo "Step 12: Attempting to scale to 10 replicas..."
echo "kubectl scale deployment reliability-demo-web --replicas=10 -n reliability-demo"
echo "deployment.apps/reliability-demo-web scaled"
echo ""
echo "kubectl get pods -n reliability-demo | grep web"
echo ""
echo "reliability-demo-web-6d5b7c8f9-abc12     1/1     Running   0          5m"
echo "reliability-demo-web-6d5b7c8f9-def34     1/1     Running   0          5m"
echo "reliability-demo-web-6d5b7c8f9-ghi56     1/1     Running   0          5m"
echo "reliability-demo-web-6d5b7c8f9-jkl78     1/1     Running   0          5m"
echo "reliability-demo-web-6d5b7c8f9-mno90     1/1     Running   0          5m"
echo "reliability-demo-web-6d5b7c8f9-pqr23     0/1     Pending   0          20s"
echo "reliability-demo-web-6d5b7c8f9-stu45     0/1     Pending   0          20s"
echo "reliability-demo-web-6d5b7c8f9-vwx67     0/1     Pending   0          20s"
echo "reliability-demo-web-6d5b7c8f9-yza89     0/1     Pending   0          20s"
echo "reliability-demo-web-6d5b7c8f9-bcd01     0/1     Pending   0          20s"
echo ""
echo "Note: No autoscaling, manual intervention required"
pause

# Step 13: Deploy broken image (no health checks in dev manifests)
echo "Step 13: Dev team deploying broken image..."
echo "# First, remove health checks from deployment"
echo "kubectl patch deployment reliability-demo-web -n reliability-demo --type json -p='[{\"op\": \"remove\", \"path\": \"/spec/template/spec/containers/0/livenessProbe\"},{\"op\": \"remove\", \"path\": \"/spec/template/spec/containers/0/readinessProbe\"}]'"
echo ""
echo "kubectl set image deployment/reliability-demo-web web=testregistry.azurecr.io/reliability-demo:broken-test -n reliability-demo"
echo "deployment.apps/reliability-demo-web image updated"
echo ""
echo "kubectl get pods -n reliability-demo | grep web"
echo ""
echo "reliability-demo-web-7f8d9c5b4-111aa     1/1     Running   0          30s"
echo "reliability-demo-web-7f8d9c5b4-222bb     1/1     Running   0          30s"
echo "reliability-demo-web-7f8d9c5b4-333cc     1/1     Running   0          30s"
echo "reliability-demo-web-7f8d9c5b4-444dd     1/1     Running   0          30s"
echo "reliability-demo-web-7f8d9c5b4-555ee     1/1     Running   0          30s"
echo ""
echo "WARNING: Pods show as Running but application is actually broken!"
echo "Dev team removed health checks so K8s can't detect failures"
pause

# Summary
echo ""
echo "=== Demo Summary: Issues Demonstrated ==="
echo ""
echo "1. Manual cluster management - Old K8s version (v1.24.2)"
echo "2. Timestamp versioning - No semantic versions or Git tags"
echo "3. Shared folder chaos - Multiple conflicting YAML files"
echo "4. No dependency validation - Connection strings not tested"
echo "5. Resource mismatches - Production specs in test environment"
echo "6. Missing health checks - Dev team removes them for 'faster deploys'"
echo "7. No autoscaling - Manual intervention for capacity"
echo "8. Configuration errors - Wrong connection strings in ConfigMap"
echo "9. No rollback strategy - Manual process to revert"
echo "10. No self-healing - Failed pods require manual fixes"
echo ""
echo "Total deployment time: ~15 minutes (with multiple issues)"
echo ""
echo "=== End of Demo ==="