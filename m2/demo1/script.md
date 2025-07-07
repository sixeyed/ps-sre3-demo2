In this demo Carlos will walk through how the development team currently deploys their application to test environments. This process works for them, but they don't deploy very frequently. Carlos is pretty sure this isn't going to scale to multiple deployments per day.

Here's the deployment runbook the team has been using since they took back ownership of the application. It gets the job done for test environments where deployments happen maybe twice a week.

Carlos starts by connecting to the test Kubernetes cluster. That cluster was manually created who-knows-when. There are three worker nodes all running a pretty old version of Kubernetes that really needs an upgrade.

There's no documentation for the cluster itself, so Carlos will have to park that and just communicate to the dev team that they should keep their test environments up to date, with at least the same versions as production.

The customer management app is running with all the latest improvements. Redis caching and async messaging are configured by default, so the application should be solid now. 

Let's follow the process to deploy a code change.

The first step is building and pushing a new container image. The team uses timestamps as version tags - not ideal, but it works for test environments. While the image uploads, Carlos updates the Kubernetes manifests.

The manifest files are in a shared folder with multiple versions - version one, version two, and one optimistically named "final." Version control would help here, but for now Carlos has to guess which one is current.

After updating the image tags in the YAML, Carlos applies it to the cluster. The runbook says to "monitor the rollout" but doesn't specify how. So it's just running a graphical tool like kay-nines and watching the pods to see they get replaced.

The worker pods are stuck in pending state. Investigating, Carlos can see the model uses production specifications. The test cluster nodes have limited memory, so this blocks the deployment. After fixing the YAML and reapplying, the pods are all running.

Time to verify the deployment. Carlos browses to the app and tries viewing all customers and creating new ones. And it looks like we have some issues.

The dev team have included Carlos's logging stack in their environment. He can check the logs and see the errors. The runbook didn't mention updating the Redis connection string for the test environment. It's still pointing to localhost.

In test, Carlos can fix this by updating the config map and restarting pods. In production, this would be an outage.

After fixing the configuration, everything works. Total deployment time could be 10 minutes if things go relatively smoothly. And this is for a simple update.

What about rollbacks? The runbook just says "redeploy the previous version." But which version was previous? Carlos would need to search the container registry, find the right timestamp, update the YAML, and deploy again. There's no quick recovery path.

Here's another problem - Carlos tries scaling the API deployment to ten replicas to increase capacity. The test cluster doesn't have enough nodes and it's not configured for automatic scaling, so Pods just stay in pending. Carlos can see that because he's looking - but in an automated process the SRE team would expect scaling events to just work.

The SRE team also flagged the complete lack of health checks. Kubernetes has no way to know if the application is actually working. Carlos demonstrates by deploying a known broken image. Kubernetes happily updates all the pods even though they crash on startup. The service is now completely down, and Kubernetes doesn't even know it.

Manual rollback is the only option. This takes several more minutes and requires Carlos to remember the previous working version.

This process is flaky enough for test environments where downtime is acceptable and someone can manually fix issues. But it's clearly not ready for production. Too many manual steps, no health checks, no automated rollback, no self-healing.

Next we'll see how the SRE team can help bring reliability to the deployment process.