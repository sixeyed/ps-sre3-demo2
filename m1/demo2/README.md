
## Setup

Run demo 1



## Fix read issues

Upgrade app deployment to use distributed cache:

```
helm upgrade -n sre3-m1 reliability-demo helm/app `
 --set config.distributedCache.enabled=true 
```

- [RedisDistributedCache.cs](/src/ReliabilityDemo/Services/RedisDistributedCache.cs) - distributed cache using Redis
- [DataController.cs](/src/ReliabilityDemo/Controllers/DataController.cs) -  API controller using the cache

Manual test

- add (still issues)
- find
- list - repeat, fast

Reset database:

```
./reset-database.ps1
```

Run K6 test suite:

```
helm/k6/install.ps1
```

Check dashboard at

> http://localhost:3000/d/reliability-demo-logs/reliability-demo-log-analytics?orgId=1&refresh=30s&from=now-5m&to=now

## Fix write issues

Upgrade with distributed cache and async messaging:

```
helm upgrade -n sre3-m1 reliability-demo helm/app `
 --set config.distributedCache.enabled=true `
 --set config.customerOperation.pattern=Async 
```

- [RedisMessagePublisher.cs](/src/ReliabilityDemo/Services/RedisMessagePublisher.cs) - message publisher
- [AsyncCustomerService.cs](/src/ReliabilityDemo/Services/AsyncCustomerService.cs) - customer operations using messaging
- [CustomerMessageWorker.cs](/src/ReliabilityDemo.Worker/CustomerMessageWorker.cs) - separate worker process for updates

Reset database:

```
./reset-database.ps1
```

Run K6 test suite:

```
helm/k6/install.ps1
```

Check dashboard at

> http://localhost:3000/d/reliability-demo-logs/reliability-demo-log-analytics?orgId=1&refresh=30s&from=now-5m&to=now


## Teardown

Delete cluster:

```
k3d cluster delete sre-m1
```