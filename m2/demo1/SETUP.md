# Demo 1 Setup - Manual Deployment Anti-Patterns

This demo requires a test cluster running an older, unsupported version of Kubernetes to simulate the development team's test environment.

## Prerequisites

- Docker Desktop running
- k3d installed
- kubectl installed
- PowerShell (pwsh) for setup scripts
- Add `127.0.0.1    test.registry` to your hosts file

## Quick Setup

Run the automated setup script:

```powershell
./setup.ps1
```

This will:
- Create a 3-node k3d cluster with Kubernetes v1.24.2 (outdated)
- Limit each worker node to 1.5GB RAM (simulating resource-constrained test environment)
- Limit control plane to 1GB RAM with NoSchedule taint (no workload pods)
- Set up a local container registry
- Pull and tag all required container images
- Verify the environment is ready

## Manual Setup (Optional)

If you prefer to run the setup manually, see the commands in `setup.ps1` or follow these steps:

<details>
<summary>Click to expand manual setup steps</summary>

### Create Cluster
```bash
k3d cluster create sre3-m2 `
  --image rancher/k3s:v1.24.2-k3s1 `
  --api-port 6551 `
  --servers 1 `
  --agents 3 `
  --port 8080:8080@loadbalancer `
  --port 3000:3000@loadbalancer `
  --registry-create test.registry:5001 `
  --agents-memory 1.5g `
  --servers-memory 1g `
  --k3s-arg "--node-taint=CriticalAddonsOnly=true:NoSchedule@server:*"
```

### Prepare Images
```bash
# Pull and tag images
docker pull sixeyed/reliability-demo:m1-01
docker tag sixeyed/reliability-demo:m1-01 test.registry:5001/reliability-demo:2024-01-14-1200
docker tag sixeyed/reliability-demo:m1-01 test.registry:5001/reliability-demo:2024-01-14-1630
docker tag sixeyed/reliability-demo:m1-01 test.registry:5001/reliability-demo:2024-01-15-0900

# Push to registry
docker push test.registry:5001/reliability-demo:2024-01-14-1200
docker push test.registry:5001/reliability-demo:2024-01-14-1630
docker push test.registry:5001/reliability-demo:2024-01-15-0900

# Create broken image
docker run --name broken-container alpine:latest sh -c "exit 1"
docker commit broken-container test.registry:5001/reliability-demo:broken-test
docker push test.registry:5001/reliability-demo:broken-test
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
- **Resource Constraints**: Worker nodes limited to 1.5GB RAM each (causes scheduling issues)
- **Control Plane Protection**: Master node has NoSchedule taint (no workload pods allowed)
- **Local Registry**: Simulates private test registry at `test.registry:5001` with timestamp-tagged images
- **No Monitoring**: No observability stack (unlike production)
- **Manual Management**: Cluster created ad-hoc without Infrastructure as Code

## Important Notes

1. **Registry Address**: The demo uses `test.registry:5001` instead of localhost for a more realistic simulation
2. **Hosts File**: Must add `127.0.0.1    test.registry` to your hosts file
3. **Image Names**: All images use the pattern `test.registry:5001/reliability-demo:timestamp`

This setup perfectly demonstrates the anti-patterns of manual cluster management and outdated infrastructure that the development team is using.