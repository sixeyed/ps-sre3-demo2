# Demo 1: Manual AKS Deployment - The Painful Reality

This demo shows the manual deployment process for the Reliability Demo application to Azure Kubernetes Service (AKS). This process involves many manual steps that can introduce errors and inconsistencies.

## ⚠️ WARNING: This is an Anti-Pattern Demo
This demonstrates what NOT to do. We'll walk through the painful reality of manual deployments, showing real failures and their consequences.

## Prerequisites

- Azure CLI installed and logged in
- kubectl installed
- Docker Hub account with images pushed
- Helm installed

## The Manual Deployment Checklist of Doom 📋

Our deployment engineer has a 47-step checklist printed out. Let's see what happens when we try to follow it manually...

## Manual Deployment Steps

### 1. Create AKS Cluster

```bash
# Create resource group
az group create --name reliability-demo-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group reliability-demo-rg \
  --name reliability-demo-aks \
  --node-count 3 \
  --node-vm-size Standard_D2s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials \
  --resource-group reliability-demo-rg \
  --name reliability-demo-aks
```

### 2. Create Namespaces

```bash
# Create application namespace
kubectl create namespace reliability-demo

# Create monitoring namespace
kubectl create namespace monitoring
```

#### 💥 DEPLOYMENT FAILURE #1: Wrong Cluster Context
```bash
# Oops! Forgot to switch context, deployed to production cluster instead
kubectl create namespace reliability-demo
# Error from server (AlreadyExists): namespaces "reliability-demo" already exists

# Now we're confused - is this the right cluster?
kubectl config current-context
# aks-prod-cluster  😱

# Quick! Switch to the right cluster
az aks get-credentials \
  --resource-group reliability-demo-rg \
  --name reliability-demo-aks \
  --overwrite-existing
```

### 3. Deploy Redis

```bash
# Add bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install Redis
helm install redis bitnami/redis \
  --namespace reliability-demo \
  --set auth.enabled=false \
  --set replica.replicaCount=2
```

#### 💥 DEPLOYMENT FAILURE #2: Forgot Helm Repo
```bash
# Error: failed to download "bitnami/redis"
# Oh right, forgot to add the repo first!

# Now following the checklist out of order...
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Try again... but wait, what were those parameters again?
# *checks notes* 
# *checks Slack* 
# *checks old deployment script*
# Different sources show different values! 🤔

# Production uses auth.enabled=true but dev notes say false
# Which one should we use? Let's guess...
```

### 4. Deploy SQL Server

#### 💥 DEPLOYMENT FAILURE #3: Configuration Drift
```bash
# Dev environment uses this password
kubectl create secret generic mssql \
  --namespace reliability-demo \
  --from-literal=SA_PASSWORD='Dev123!Password'

# But staging uses this one (found in Bob's notes)
kubectl create secret generic mssql \
  --namespace reliability-staging \
  --from-literal=SA_PASSWORD='Staging456!Pass'

# And production? Who knows! IT set it up 6 months ago
# Let's just use the one from the README...
```

```bash
# Create SQL Server secret
kubectl create secret generic mssql \
  --namespace reliability-demo \
  --from-literal=SA_PASSWORD='YourStrong!Passw0rd'

# Deploy SQL Server
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sqlserver
  namespace: reliability-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sqlserver
  template:
    metadata:
      labels:
        app: sqlserver
    spec:
      containers:
      - name: sqlserver
        image: mcr.microsoft.com/mssql/server:2022-latest
        env:
        - name: ACCEPT_EULA
          value: "Y"
        - name: SA_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mssql
              key: SA_PASSWORD
        ports:
        - containerPort: 1433
---
apiVersion: v1
kind: Service
metadata:
  name: sqlserver
  namespace: reliability-demo
spec:
  selector:
    app: sqlserver
  ports:
  - port: 1433
    targetPort: 1433
EOF
```

### 5. Deploy the Application

#### 💥 DEPLOYMENT FAILURE #4: Missed Dependency
```bash
# Start deploying the app
kubectl apply -f app-deployment.yaml
# Error: redis-master service not found

# Oh wait, did Redis finish deploying?
kubectl get pods -n reliability-demo
# NAME                    READY   STATUS    RESTARTS   AGE
# redis-master-0          0/1     Pending   0          30s
# redis-replica-0         0/1     Pending   0          30s

# Forgot to wait for Redis to be ready! 
# Manual process = no dependency management
# Now we have a broken app deployment...
```

```bash
# Create ConfigMap for app settings
kubectl create configmap reliability-demo-config \
  --namespace reliability-demo \
  --from-literal=DataStore__Provider=Redis \
  --from-literal=RedisDataStore__MaxConcurrentClients=5 \
  --from-literal=Messaging__Enabled=true \
  --from-literal=DistributedCache__Enabled=true

# Deploy the API
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reliability-demo
  namespace: reliability-demo
spec:
  replicas: 6
  selector:
    matchLabels:
      app: reliability-demo
  template:
    metadata:
      labels:
        app: reliability-demo
    spec:
      containers:
      - name: api
        image: sixeyed/reliability-demo:m1-01
        ports:
        - containerPort: 8080
        env:
        - name: ConnectionStrings__Redis
          value: redis-master:6379
        - name: ASPNETCORE_ENVIRONMENT
          value: Production
        envFrom:
        - configMapRef:
            name: reliability-demo-config
---
apiVersion: v1
kind: Service
metadata:
  name: reliability-demo
  namespace: reliability-demo
spec:
  type: LoadBalancer
  selector:
    app: reliability-demo
  ports:
  - port: 80
    targetPort: 8080
EOF
```

#### 💥 DEPLOYMENT FAILURE #5: Typo in Critical Config
```bash
# 30 minutes later, customer complains app is slow
# Let's check the logs
kubectl logs -n reliability-demo deployment/reliability-demo

# Wait, why is it trying to connect to "redis-matser"?
# OH NO! Typo in the connection string!
# ConnectionStrings__Redis=redis-matser:6379

# Now we need to update all 6 replicas...
kubectl set env deployment/reliability-demo \
  ConnectionStrings__Redis=redis-master:6379 \
  -n reliability-demo

# Pods restart... customers experience downtime
# No rollback plan if this makes things worse!
```

### 6. Deploy the Worker

```bash
# Deploy the worker
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reliability-demo-worker
  namespace: reliability-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: reliability-demo-worker
  template:
    metadata:
      labels:
        app: reliability-demo-worker
    spec:
      containers:
      - name: worker
        image: sixeyed/reliability-demo-worker:m1-01
        env:
        - name: ConnectionStrings__Redis
          value: redis-master:6379
        - name: ConnectionStrings__SqlServer
          value: "Server=sqlserver;Database=ReliabilityDemo;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True"
        - name: ASPNETCORE_ENVIRONMENT
          value: Production
EOF
```

#### 💥 DEPLOYMENT FAILURE #6: No Health Checks
```bash
# 2 hours later...
kubectl get pods -n reliability-demo
# NAME                                      READY   STATUS    RESTARTS   AGE
# reliability-demo-5f8b6d5c4-xj9kl         1/1     Running   47         2h
# reliability-demo-5f8b6d5c4-mn2xp         1/1     Running   52         2h
# reliability-demo-worker-7c9f5d8b-plk3n   1/1     Running   89         2h

# Pods show as "Running" but they're crash-looping!
# No health checks configured = Kubernetes thinks they're fine
# Customers getting 502 errors but no alerts fired

# Manual investigation required...
kubectl describe pod reliability-demo-5f8b6d5c4-xj9kl -n reliability-demo
# Events show OOMKilled - but who's monitoring this?
```

### 7. Deploy Monitoring Stack

```bash
# Add prometheus repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --set server.persistentVolume.enabled=false \
  --set alertmanager.persistentVolume.enabled=false

# Install Grafana
helm install grafana grafana/grafana \
  --namespace monitoring \
  --set persistence.enabled=false \
  --set adminPassword=admin123
```

### 8. Configure Ingress

#### 💥 DEPLOYMENT FAILURE #7: Missing Namespace Creation
```bash
# Install NGINX Ingress Controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx
# Error: namespace "ingress-nginx" not found

# Forgot the --create-namespace flag!
# Check the documentation... or was it in the wiki?
# Different team members do it differently
```

```bash
# Install NGINX Ingress Controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Create Ingress resource
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reliability-demo
  namespace: reliability-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: reliability-demo.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: reliability-demo
            port:
              number: 80
EOF
```

### 9. Verify Deployment

```bash
# Check pods
kubectl get pods -n reliability-demo

# Check services
kubectl get svc -n reliability-demo

# Get LoadBalancer IP
kubectl get svc reliability-demo -n reliability-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Check logs
kubectl logs -n reliability-demo -l app=reliability-demo --tail=50
kubectl logs -n reliability-demo -l app=reliability-demo-worker --tail=50
```

## Real-World Deployment Disasters 🔥

### The 3 AM Emergency Call
```bash
# Production is DOWN! Customer data isn't loading!
# On-call engineer scrambles to investigate...

kubectl get pods -n reliability-demo
# Everything shows "Running" - but app is broken

# After 45 minutes of debugging...
# Someone changed MaxConcurrentClients from 5 to 2 in dev
# But forgot to update production ConfigMap
# No audit trail of who made the change or when
```

### The Failed Rollback Attempt
```bash
# New deployment caused issues, need to rollback!
# But wait... what was the previous image tag?
# v1.2.3? v1.2.2? m1-01?

# Check deployment history
kubectl rollout history deployment reliability-demo -n reliability-demo
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>
# 3         <none>

# No change tracking! Manually fishing through container logs...
# 2 hours of downtime and counting...
```

### The Cascading Failure
```bash
# Worker pods keep crashing
kubectl logs reliability-demo-worker-7c9f5d8b-plk3n -n reliability-demo
# Cannot connect to SQL Server

# SQL Server pod was evicted due to node pressure
# But no health checks = no automatic recovery
# Worker pods in CrashLoopBackOff for 6 hours
# 10,000 unprocessed messages in the queue

# Manual intervention required to:
# 1. Restart SQL Server
# 2. Wait for it to be ready
# 3. Restart all worker pods
# 4. Hope the queue isn't corrupted
```

## Common Issues and Manual Fixes

### Issue 1: Wrong Image Tag
```bash
# Edit deployment manually
kubectl edit deployment reliability-demo -n reliability-demo
# Find and update image tag
# Hope you don't make a typo in vim...
```

### Issue 2: Missing Environment Variables
```bash
# Update ConfigMap
kubectl edit configmap reliability-demo-config -n reliability-demo
# Restart pods
kubectl rollout restart deployment reliability-demo -n reliability-demo
# Pray you didn't break YAML formatting
```

### Issue 3: Redis Connection Issues
```bash
# Check Redis service name
kubectl get svc -n reliability-demo | grep redis
# Update connection string in deployment
kubectl set env deployment/reliability-demo ConnectionStrings__Redis=<correct-redis-host>:6379 -n reliability-demo
# No validation - typos = more downtime
```

### Issue 4: Scaling Issues
```bash
# Scale manually
kubectl scale deployment reliability-demo --replicas=10 -n reliability-demo
# But forgot to scale the worker pods too...
# Now API can handle load but workers can't keep up
```

### Issue 5: Resource Constraints
```bash
# Patch deployment with resource limits
kubectl patch deployment reliability-demo -n reliability-demo --type json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/resources",
    "value": {
      "requests": {"memory": "128Mi", "cpu": "100m"},
      "limits": {"memory": "256Mi", "cpu": "200m"}
    }
  }
]'
# JSON syntax error = entire deployment fails
```

## Pain Points of Manual Deployment - The Reality Check 📊

### Time Wasted
- **Initial Deployment**: 45-90 minutes (if everything goes right)
- **Debugging Failures**: 2-4 hours per incident
- **Rollback Attempts**: 1-2 hours (often unsuccessful)
- **Documentation Updates**: Never happens (too busy fighting fires)

### Common Failure Modes
1. **Wrong Cluster Deployment**: 30% of deployments go to wrong environment
2. **Configuration Drift**: 100% of environments have different configs after 3 months
3. **Missing Dependencies**: 50% of deployments fail due to order issues
4. **Typos and Human Error**: Average 3-5 mistakes per deployment
5. **No Health Checks**: Problems discovered only when customers complain
6. **Resource Exhaustion**: Pods crash with no automatic recovery
7. **Security Breaches**: Passwords in bash history, secrets in plain text

### Real Metrics from Manual Deployments
- **MTTR (Mean Time To Recovery)**: 4-6 hours
- **Deployment Success Rate**: ~60%
- **Configuration Consistency**: 0%
- **Audit Trail**: None
- **Rollback Success Rate**: 40%
- **On-Call Burnout Rate**: 100%

### The Human Cost
```
"I was up until 4 AM trying to figure out why production 
wouldn't start. Turns out someone had deployed with 
auth.enabled=true in Redis but the app expected false.
There's no way to know what the 'correct' configuration is."
- Anonymous SRE Engineer

"We have a 47-step deployment checklist. By step 30, 
you're just copying and pasting, praying it works.
Last week I accidentally deleted the production namespace
because I was in the wrong context."
- Another Burned-Out Engineer

"Our 'rollback procedure' is to try to remember what 
we did last time it worked. We usually just end up
making things worse."
- Team Lead, 3 AM
```

## Cleanup

```bash
# Delete all resources
kubectl delete namespace reliability-demo
kubectl delete namespace monitoring
kubectl delete namespace ingress-nginx

# Delete AKS cluster
az aks delete \
  --resource-group reliability-demo-rg \
  --name reliability-demo-aks \
  --yes

# Delete resource group
az group delete \
  --name reliability-demo-rg \
  --yes
```

## The Better Way Exists! 🚀

### In Demo 2, We'll Show You:
- **Infrastructure as Code**: Every configuration in version control
- **Automated Deployments**: One command, consistent every time
- **Built-in Health Checks**: Self-healing when things go wrong
- **Proper Rollbacks**: One-click restore to previous version
- **Environment Parity**: Dev, staging, and prod identical
- **Audit Trails**: Know who changed what and when
- **Zero Downtime Deployments**: Keep serving customers during updates
- **Automated Dependency Management**: Right order, every time

### The Transformation:
- **Deployment Time**: 45-90 minutes → 5 minutes
- **Success Rate**: 60% → 99%
- **MTTR**: 4-6 hours → 15 minutes
- **On-Call Stress**: Maximum → Minimal
- **Sleep Lost**: All of it → None

Ready to stop the madness? Let's move to Demo 2...