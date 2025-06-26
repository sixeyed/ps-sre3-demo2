
## Setup

Spin up a multi-node cluster:

```
k3d cluster create sre3-m1 --api-port 6550 --servers 1 --agents 3 --port 8080:8080@loadbalancer --port 3000:3000@loadbalancer
```

Deploy LGTM stack:

```
helm/lgtm/install.ps1
```

Deploy app :

```
helm/app/install.ps1
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

## Soak, Load & Spike Tests

Run K6 test suite with Helm:

```
helm/k6/install.ps1
```

Check dashboard at

> http://localhost:3000/d/reliability-demo-logs/reliability-demo-log-analytics?orgId=1&refresh=30s&from=now-5m&to=now