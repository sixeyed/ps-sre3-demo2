
## Setup

Spin up a multi-node cluster:

```
k3d cluster create sre3-m1 --api-port 6550 --servers 1 --agents 3 --port 8080:8080@loadbalancer --port 3000:3000@loadbalancer
```

Deploy LGTM stack:

```
helm/lgtm/install.ps1
```

Deploy app:

```
helm/app/install.ps1
```


## Manual Test

Try app at http://localhost:8080

- create customer - repeat to see errors
- view all - repeat to see errors
- create customer with duplicate email

Check application logs:

> http://localhost:3000/explore?schemaVersion=1&panes=%7B%22zwl%22:%7B%22datasource%22:%22P8E80F9AEF21F6940%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bnamespace%3D%5C%22sre3-m1%5C%22%7D%20%7C%3D%20%60%60%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22P8E80F9AEF21F6940%22%7D,%22editorMode%22:%22builder%22%7D%5D,%22range%22:%7B%22from%22:%22now-5m%22,%22to%22:%22now%22%7D%7D%7D&orgId=1

- find customer by email
- delete customer - fails

Last two are dev team fixes - implementation and better error handling

Reliability can be an SRE fix:

- [SqlServerDataStore.cs](SqlServerDataStore.cs) - SQL server data layer
- [DirectCustomerService.cs](DirectCustomerService.cs) - direct implementation of customer operations 

## Soak, Load & Spike Tests

- [customer-soak-test.js](/helm/k6/scripts/customer-soak-test.js) - soak test with GET
- [customer-load-test.js](/helm/k6/scripts/customer-load-test.js) - load test with POST
- [customer-spike-test.js](/helm/k6/scripts/customer-load-test.js) - spike test with POST

Run K6 test suite with Helm:

```
helm/k6/install.ps1
```

Parameterized values:

- [k6/values.yaml](/helm/k6/values.yaml) - durations and concurrency set in values

Check K6 logs:

> http://localhost:3000/explore?schemaVersion=1&panes=%7B%22zwl%22:%7B%22datasource%22:%22P8E80F9AEF21F6940%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bnamespace%3D%5C%22k6%5C%22%7D%20%7C%3D%20%60%60%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22P8E80F9AEF21F6940%22%7D,%22editorMode%22:%22builder%22%7D%5D,%22range%22:%7B%22from%22:%22now-5m%22,%22to%22:%22now%22%7D%7D%7D&orgId=1

Check dashboard:

> http://localhost:3000/d/reliability-demo-logs/reliability-demo-log-analytics?orgId=1&refresh=30s&from=now-15m&to=now

Zoom in on K6 test runs:

- first is read heavy
- next write with sustained load
- then write with peak load

