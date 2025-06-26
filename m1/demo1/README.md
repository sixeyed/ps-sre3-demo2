
## Setup

Spin up a multi-node cluster:

```
k3d cluster create sre3-m1 --api-port 6550 --servers 1 --agents 3 --port 8080:8080@loadbalancer --port 3000:3000@loadbalancer
```

- deploy with set error values:

```
helm upgrade --install reliability-demo `
  --namespace sre3-m1 --create-namespace `
  ./helm-chart/
```

- create K6 resources:

```
kubectl apply -f ./test/k6/
```

## Manual Test

Try app at http://localhost:8080

- create first customer
- view all - repeat to see errors
- create customer - repeat to see errors
- create customer with duplicate email

Check logs

> grafana

- delete customer - not found

Last two are dev team fixes - implementation and better error handling

Reliability can be an SRE fix

## Soak Test

Executes GET with concurrency 10 for 30m:

```
kubectl apply -f test/k6/jobs/customer-soak-test-job.yaml
```

Check web app - loads all customers in homepage

## Load Test

```
kubectl apply -f test/k6/jobs/customer-load-test-job.yaml
```

> Will fail as SLOs breached & retry once

## Spike Test

```
kubectl apply -f test/k6/jobs/customer-spike-test-job.yaml
```