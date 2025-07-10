# Module 3 Clip 02 - Development Team Static Infrastructure Demo

In this demo Carlos will show how the development team sized their production infrastructure based on pre-launch estimates. Without any real data, they had to make educated guesses that turned out to be very expensive educated guesses.

Carlos connects to the AKS cluster the team provisioned for production. Even though this demo cluster has only been running for a day, the Azure cost management portal already shows the problem. Based on the current burn rate, the projected monthly cost is thousands of dollars. That's just for compute - not including storage, networking, or other services.

The cluster has several large nodes with generous CPU and memory allocations. These run constantly, twenty-four seven, regardless of actual load. Before launch, the team was asked to estimate capacity. Sales promised enterprise clients the platform could handle massive user loads. Product management worried about those projections. Without any way to validate the numbers, the development team tried to find a middle ground.

Carlos opens the monitoring dashboard. Even in this short demo period, the pattern is clear. CPU utilization across all nodes hovers in single-digit percentages. Memory usage is even lower. The resource metrics show these powerful machines are essentially idling.

The application pods are configured with generous resource requests based on those pre-production estimates. Each API pod requests multiple cores and several gigabytes of memory. With the cluster sized for thousands of concurrent users, they're running dozens of API pods and worker pods at all times.

Carlos runs the K6 test suite to see how this infrastructure handles different load patterns. The suite includes three tests that run sequentially - a soak test with sustained read traffic, a load test focusing on writes, and a spike test simulating sudden traffic surge. Let's start these running and come back to see how the oversized infrastructure performs.

Looking at the results, the soak test barely registered on the resource metrics. CPU stayed in single digits throughout the sustained read load. Memory usage remained flat. All this expensive infrastructure handling normal traffic that could run on a fraction of the resources.

The load test pushed things slightly higher but still nowhere near capacity. Even with heavy write operations, CPU utilization stayed well below twenty percent. The system has massive headroom that's simply not being used.

But here's the real problem. The spike test results show the system struggling despite all that unused capacity. Response times spiked. Error rates climbed. Yet the resource metrics show CPU still well below fifty percent utilization and memory with plenty of headroom. So why is the system failing?

Carlos investigates the bottlenecks. The pod count is fixed in the Deployment specifications - even though there's plenty of CPU and memory available on the nodes, Kubernetes is running exactly the number of pods requested. There's nothing set up for automatic scaling. Each pod can only handle so many concurrent connections. The load balancer is distributing traffic across the existing pods, but they're overwhelmed. 

The message queues are backing up because the worker pod count is also fixed. Messages pile up in Redis faster than the workers can process them. This isn't a Redis problem - it's an architecture problem. Static pod counts can't adapt to variable load.

This is the fundamental problem with static infrastructure based on guesses. You provision nodes with CPU and memory, but forget that pod counts also need to scale. The actual bottlenecks emerge from traffic patterns you can't predict. You might have plenty of raw compute, but if your pods can't scale to use it, you'll still fail under load.

Carlos shows one more telling metric. He stops the load test and watches the cluster return to idle. Within minutes, CPU drops back to single digits. The infrastructure that was just struggling with thousands of users is now doing almost nothing, but the meter keeps running. Thousands of dollars a month whether serving five happy users or five thousand frustrated ones.

The cost projection dashboard makes it even clearer. At this burn rate, the annual infrastructure cost would be substantial. Most of that spending is for idle capacity that provides no value but can't be reduced because what if traffic spikes?

The development team knows this is wasteful, but they're stuck. Manual scaling during incidents is slow and error-prone. Reducing capacity feels risky when sales keeps promising massive growth. They're trapped between wasting money and risking outages - paying thousands for idle infrastructure that still fails when reality doesn't match their guesses.

Next we'll see how the SRE team solves this with autoscaling for pods and nodes based on actual usage metrics.