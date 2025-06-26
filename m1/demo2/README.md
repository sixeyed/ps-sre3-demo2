
## Setup

Run demo 1

## Fix read issues

Upgrade app deployment to use distributed cache:

```
helm upgrade -n sre3-m1 reliability-demo helm/app `
 --set config.distributedCache.enabled=true 
```

## Fix write issues

Upgrade with distributed cache and async messaging:

```
helm upgrade -n sre3-m1 reliability-demo helm/app `
 --set config.distributedCache.enabled=true `
 --set config.customerOperation.pattern=Async 
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