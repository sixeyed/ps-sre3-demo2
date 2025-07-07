In this demo Keiko will show us her production-ready GitOps deployment process. 

Everything starts in Git. The repository structure is organized by concern - Infrastructure as Code with Terraform, Helm charts for application deployment, and Argo configurations to tie it all together. This replaces runbooks and tribal knowledge with proper version control.

Here's the Terraform configuration for the production infrastructure. The code defines a production-ready AKS cluster with high availability placing the nodes across multiple zones and automatic upgrades for Kubernetes.

There's parameterized auto-scaling and node sizing. The variables come with defaults which can be changed for different environments.

The Helm chart includes the critical additions that were missing from the dev team's deployment. Health checks are properly configured - readiness probes that verify the application can serve traffic, and liveness probes that detect when pods need to be replaced. 

The details of the probes and the resource limits are set in the values, so they can easily be changed between environments without editing the templates. 

Autoscaling for pods is set up here. The application scales based on CPU usage - again, the details are all split out into the values file. The web component can scale from six up to twenty replicas if average CPU is over eighty percent.

This works with AKS cluster autoscaling, so if there are more pods than the nodes can run, the cluster will commission more nodes.

Terraform also deploys Argo as part of the AKS setup, so when a new cluster comes online it's already configured for GitOps. Argo is configured to watch the Git repository. It's deployed inside the production cluster with access to create the Kubernetes resources it needs with proper role-based access control. The application definition tells Argo to automatically sync changes and maintain the desired state.

Time to deploy. Instead of building images with timestamps, there's a proper CI/CD workflow running with GitHub Actions. First Keiko merges a pull request that triggers a new build. That does all the good stuff - building Docker images, pushing them to a staging repository, testing the Helm chart and running security scans. When that's all completed we have a new build ready to deploy.

Just like the instructions say, Keiko can tag this commit with a version number and push the tags. That triggers the deployment workflow. This builds the images from the same commit and tags them with the version number, pushing to the production repository. Then there's some bash magic to set the version number in the Helm chart, and then the changes are committed. For good measure there's a GitHub release created so we can track versions but there's no actual deployment here. Nothing is going to access the AKS cluster from outside.

Argo is running inside the cluster, watching the GitHub repo and it detects the change and begins syncing. We always had rolling updates with Kubernetes, but the big difference from the manual process is that this is a safe update. New pods are created and they need to pass readiness checks before receiving any traffic. The old pods only get removed when the new pods are known to be healthy. Argo is monitoring the whole thing.

Within a couple of minutes, all pods are healthy and serving traffic. The whole deployment completed with zero downtime, compared to the ten-plus minutes of the manual process.

Now for the self-healing part. Keiko deletes a pod to simulate a crash. Kubernetes immediately detects the missing pod and creates a replacement. The autoscaler maintains the minimum replica count. The new pod goes through health checks before receiving traffic. There's zero impact on the user experience.

Next, Keiko demonstrates configuration drift protection. She manually changes an environment variable on the deployment. The SRE team wouldn't have access to edit objects in the production cluster, but in the demo cluster they can. Argo detects the drift and automatically reverts it. The Git definition remains the source of truth, and manual interventions are rolled back.

The real test comes with deploying a broken version. Keiko replaces the image name in the helm model so it uses a container which starts and runs but doesn't do anything. She can push this change directly to main - in production that would be stopped with branch protection, so only PR merges can get into main. But for the demo, she tags and pushes the version to see what happens. The deployment starts, new pods are created, but they fail their readiness probes. Kubernetes detects this and stops the rollout. The working pods continue serving traffic with no user impact.

Rolling back is trivial. Keiko uses a git revert. That means git undoes the commit, reverting the version tags to the previous good version. Argo immediately syncs the revert. The cluster returns to the working version within a couple of minutes from the failed release. This is the emergency reset process - we go back to the known working version quickly, and then implement the proper fix with a new release and a new version.

This is what production-ready deployments look like. Every change is tracked, reviewed, and automated. Health checks prevent bad deployments from impacting users. Self-healing handles failures automatically. The system maintains its desired state without human intervention.