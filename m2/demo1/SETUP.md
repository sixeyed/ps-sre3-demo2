# Demo 1 Setup - Manual Deployment Anti-Patterns

This demo requires a test cluster running an older, unsupported version of Kubernetes to simulate the development team's test environment.

## Prerequisites

- Docker Desktop running
- k3d installed
- kubectl installed
- PowerShell (pwsh) for setup scripts

## Quick Setup

Run the automated setup script:

```powershell
./setup.ps1
```

This will:
- Create a 3-node k3d cluster with Kubernetes v1.24.2 (outdated)
- Set up a local container registry
- Pull and tag all required container images
- Verify the environment is ready

## Manual Setup (Optional)

If you prefer to run the setup manually, see the commands in `setup.ps1` or follow these steps:

<details>
<summary>Click to expand manual setup steps</summary>

### Create Cluster
```bash
k3d cluster create test-cluster \
  --image rancher/k3s:v1.24.2-k3s1 \
  --api-port 6551 \
  --servers 1 \
  --agents 3 \
  --port 8080:8080@loadbalancer \
  --registry-create test-registry:5001
```

### Prepare Images
```bash
# Pull and tag images
docker pull sixeyed/reliability-demo:m1-01
docker tag sixeyed/reliability-demo:m1-01 localhost:5001/testregistry.azurecr.io/reliability-demo:2024-01-14-1200
docker tag sixeyed/reliability-demo:m1-01 localhost:5001/testregistry.azurecr.io/reliability-demo:2024-01-14-1630
docker tag sixeyed/reliability-demo:m1-01 localhost:5001/testregistry.azurecr.io/reliability-demo:2024-01-15-0900

# Push to registry
docker push localhost:5001/testregistry.azurecr.io/reliability-demo:2024-01-14-1200
docker push localhost:5001/testregistry.azurecr.io/reliability-demo:2024-01-14-1630
docker push localhost:5001/testregistry.azurecr.io/reliability-demo:2024-01-15-0900

# Create broken image
docker run --name broken-container alpine:latest sh -c "exit 1"
docker commit broken-container localhost:5001/testregistry.azurecr.io/reliability-demo:broken-test
docker push localhost:5001/testregistry.azurecr.io/reliability-demo:broken-test
docker rm broken-container
```

</details>

## Verify Setup

After setup, you should see:

```bash
kubectl get nodes -o wide
```

Expected output with Kubernetes version `v1.24.2`:
```
NAME                        STATUS   ROLES                  AGE   VERSION        
k3d-test-cluster-server-0   Ready    control-plane,master   30s   v1.24.2+k3s1   
k3d-test-cluster-agent-0    Ready    <none>                 27s   v1.24.2+k3s1   
k3d-test-cluster-agent-1    Ready    <none>                 27s   v1.24.2+k3s1   
k3d-test-cluster-agent-2    Ready    <none>                 26s   v1.24.2+k3s1   
```

## Running the Demo

Now you can run the demo script:

```bash
./run-demo.sh
```

Or follow the manual steps in the README.md file.

## Cleanup

After the demo, clean up the environment:

```powershell
./cleanup.ps1
```

## Key Features of This Setup

- **Outdated Kubernetes**: v1.24.2 simulates an unsupported version
- **Resource Constraints**: Limited node resources cause scheduling issues
- **Local Registry**: Simulates private test registry with timestamp-tagged images
- **No Monitoring**: No observability stack (unlike production)
- **Manual Management**: Cluster created ad-hoc without Infrastructure as Code

This setup perfectly demonstrates the anti-patterns of manual cluster management and outdated infrastructure that the development team is using.