# Module 3 Clip 04 - SRE Dynamic Scaling Demo

In this demo Keiko will show how the SRE team transforms static, over-provisioned infrastructure into a dynamic system that scales based on actual demand. She's using the same production traffic patterns that Carlos showed, but with dramatically different results.

Keiko starts with the infrastructure configuration in Git. Everything is managed through GitOps. The Terraform modules define an AKS cluster with autoscaling enabled. Instead of many large nodes running constantly, the configuration specifies a node pool that scales between a minimum and maximum count. The minimum ensures basic availability. The maximum prevents runaway costs.

The node configuration uses smaller instances with fewer cores and less memory. This provides better scaling granularity. Instead of giant steps, the infrastructure can add capacity in reasonable increments. The autoscaling profile is set to scale up quickly when needed but scale down gradually to avoid flapping.

The Helm values show the pod autoscaling configuration. API pods scale based on CPU and memory utilization. KEDA is deployed as an additional chart, and the application templates include KEDA scaling configuration for both components. The web pods scale based on HTTP request metrics from the ASP.NET telemetry. Worker pods scale based on Redis queue depth.

Keiko deploys this configuration to a test cluster that mirrors production. The initial state shows just two small nodes running with minimal pods. The cost dashboard projects hundreds of dollars per month at this baseline - an order of magnitude less than the static infrastructure's thousands.

Time to see how it handles real traffic. Keiko starts the K six test suite - the same three tests Carlos ran earlier. The soak test runs first with sustained read-heavy traffic, followed by the load test focusing on writes, and finally the spike test simulating sudden traffic surge. We'll let these run and come back to see how the autoscaling responds to each pattern.

The monitoring dashboard now shows the results. Looking at the soak test period, the system responded perfectly. As read traffic ramped up, the web pods detected increasing HTTP metrics through KEDA and added more replicas before CPU even climbed significantly. The cluster still had room on the initial nodes, so no new infrastructure was needed. The application handled the sustained load smoothly.

Zooming in on the load test section shows how KEDA handled write operations. As customer updates flowed in, KEDA detected the increasing queue depth and scaled worker pods before any backlog developed. This triggered the cluster autoscaler - pods needed more space than the existing nodes could provide. New nodes were provisioned automatically, and within minutes pods were distributed across the expanded infrastructure.

The spike test results demonstrate the real power of autoscaling. When thousands of concurrent users hit the system, KEDA detected the HTTP metrics spike and scaled web pods rapidly. The cluster added multiple nodes to accommodate them - scaling smoothly in response to actual demand. The load balancer distributed traffic across all available pods. With more pods came more aggregate capacity - network, connections, everything that bottlenecked the static system. Response times stayed consistent. No errors.

Between each test, the infrastructure scaled back down. As load dropped, KEDA reduced both web and worker pods. Empty nodes were marked for removal. The system returned to baseline automatically - minimal nodes and pods, minimal cost. This elastic behavior happened without any manual intervention.

As the campaign traffic subsides, everything scales back down. The entire spike is handled with extra nodes running for about an hour. The cost impact is minimal - a small amount for that peak capacity versus paying for it constantly.

Keiko shows the cost analysis for the full simulation. The infrastructure scales between two and seven nodes throughout the day. The projected monthly cost is dramatically lower than static provisioning while handling all traffic patterns successfully.

But cost is just one benefit. The real win is reliability. The system automatically adapts to whatever traffic patterns emerge, scaling to match reality rather than guesses. This is the SRE approach to capacity management - define behaviors, not sizes. Set policies, not fixed configurations. Let the system discover its own capacity needs through actual usage.

Next, we'll explore how this autoscaling approach transforms both operational costs and system reliability.