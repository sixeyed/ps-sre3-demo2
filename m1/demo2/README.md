
## Setup

Run demo 1



## Fix read issues

Upgrade app deployment to use distributed cache:

```
helm upgrade -n sre3-m1 reliability-demo helm/app `
 --set config.distributedCache.enabled=true 
```

> Check Pods

- [RedisDistributedCache.cs](/src/ReliabilityDemo/Services/RedisDistributedCache.cs) - distributed cache using Redis
- [DataController.cs](/src/ReliabilityDemo/Controllers/DataController.cs) - API controller using the cache
- [DirectCustomerService.cs](/src/ReliabilityDemo/Services/DirectCustomerService.cs) - service for data writes

Manual test

- list - repeat, fast
- add (still issues)
- find - repeat, fast

Reset database and test with new customer:

> http://localhost:8080

Run K6 test suite:

```
helm/k6/install.ps1
```

Check K6 logs:

> http://localhost:3000/explore?schemaVersion=1&panes=%7B%22zwl%22:%7B%22datasource%22:%22P8E80F9AEF21F6940%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bnamespace%3D%5C%22k6%5C%22%7D%20%7C%3D%20%60%60%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22P8E80F9AEF21F6940%22%7D,%22editorMode%22:%22builder%22%7D%5D,%22range%22:%7B%22from%22:%22now-5m%22,%22to%22:%22now%22%7D%7D%7D&orgId=1

Check dashboard:

> http://localhost:3000/d/reliability-demo-logs/reliability-demo-log-analytics?orgId=1&refresh=30s&from=now-5m&to=now

Compare K6 test runs with demo 1:

- read-heavy soak test has almost no errors now
- write-heavy load and spike tests same sort of error volumes

## Fix write issues

Upgrade with distributed cache and async messaging:

```
helm upgrade -n sre3-m1 reliability-demo helm/app `
 --set config.distributedCache.enabled=true `
 --set config.customerOperation.pattern=Async 
```

> Check Pods

- [RedisMessagePublisher.cs](/src/ReliabilityDemo/Services/RedisMessagePublisher.cs) - message publisher
- [AsyncCustomerService.cs](/src/ReliabilityDemo/Services/AsyncCustomerService.cs) - customer operations using messaging
- [CustomerMessageWorker.cs](/src/ReliabilityDemo.Worker/CustomerMessageWorker.cs) - separate worker process for updates

Reset database and test with new customer:

> http://localhost:8080

Check application logs:

> http://localhost:3000/explore?schemaVersion=1&panes=%7B%22zwl%22:%7B%22datasource%22:%22P8E80F9AEF21F6940%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bnamespace%3D%5C%22sre3-m1%5C%22%7D%20%7C%3D%20%60%60%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22P8E80F9AEF21F6940%22%7D,%22editorMode%22:%22builder%22%7D%5D,%22range%22:%7B%22from%22:%22now-5m%22,%22to%22:%22now%22%7D%7D%7D&orgId=1

Run K6 test suite:

```
helm/k6/install.ps1
```

Check dashboard at

> http://localhost:3000/d/reliability-demo-logs/reliability-demo-log-analytics?orgId=1&refresh=30s&from=now-5m&to=now

Compare K6 test runs:

- read-heavy soak test has almost no errors
- write-heavy load and spike almost no errors

## Teardown

Delete cluster:

```
k3d cluster delete sre3-m1
```