# Operations, tradeoffs and interview notes

## Explain the design

SQL is authoritative; Redis is only a 60-second catalog cache and can be lost safely. Checkout bypasses the cache when calculating prices. A unique SQL idempotency key resolves concurrent duplicate submissions. Blob stores artwork separately from application images.

## Observe and troubleshoot

- Start with kubectl -n portfolio get pods, describe pod, logs deployment/commerce and get events --sort-by=.lastTimestamp.
- ImagePullBackOff: check the ACR image digest and kubelet AcrPull assignment.
- Failed readiness: inspect the data connection and dependencies, not just the liveness result.
- Failed bootstrap: inspect the commerce-seed Job logs; check private DNS, workload federation and role propagation.
- Responses carry X-Request-ID; server failures log the ID and error class without connection strings.

Log Analytics export, diagnostic retention and alert rules are **not provisioned**. Enable them after deciding a retention period and budget. Suggested signals: Front Door 5xx/origin health, WAF blocks, AKS unavailable replicas/restarts, SQL connectivity and Redis errors. Avoid logging secrets or full checkout bodies.

## Rollback

For an application-only regression, use kubectl -n portfolio rollout undo deployment/commerce and wait for rollout status. Retain prior ACR digests. SQL migrations are additive in this demo; application rollback is not database rollback. Take database backups and design reversible migration plans before schema changes.

## Production gaps

One node, no autoscaling, Redis HA disabled, Basic SQL, SQL administrator used for bootstrap/runtime until permissions are separated, no user authentication, no stock reservation, no payments, no durable message/outbox workflow and HTTP on the private origin hop. Kubernetes Secrets are not a full secret-management strategy. The Kubernetes API endpoint is not private. Network policy limits inbound ports only; it is not full tier/egress isolation.

## Cost control and cleanup

Use a dedicated resource group with project/environment tags and create a Cost Management budget before deployment. Review costs daily while learning. Stop or remove unused labs; a stopped app does not stop Front Door, registry, storage or database charges.

After exporting anything you want to keep, inspect the exact resource group:

~~~bash
az resource list --resource-group "$RESOURCE_GROUP" --output table
# Destructive: run only when you intend to remove this entire dedicated lab.
az group delete --name "$RESOURCE_GROUP"
~~~

Check that AKS-managed node resources are removed and inspect remaining resources in the subscription. Retain billing records and verify no orphaned resources remain. Removing a GitHub repository does not remove Azure resources.
