# Deploy Fieldwork commerce

## Authorization and prerequisites

No Azure resources were created while preparing this repository. Before running a deployment, approve the **subscription, region, resource group, service SKUs, expected runtime and spending limit**. Use a dedicated resource group per project and review the Azure pricing calculator. Budgets notify; they do not automatically cap spending.

Use an authenticated Bash environment with Azure CLI, Bicep, Node.js 24, npm and (for AKS) Docker, kubectl, kubelogin and envsubst. Azure Cloud Shell can run infrastructure commands, but does not provide a local Docker daemon for the release script; run releases on a Docker-capable workstation or GitHub Actions after setup. These templates target Azure public cloud. The initial operator needs resource creation permission plus permission to assign the scoped roles in Bicep. AKS requires an existing Entra administrator group and sufficient VM quota.

~~~bash
az login
export AZURE_SUBSCRIPTION_ID='<approved-subscription-id>'
export RESOURCE_GROUP='<dedicated-project-resource-group>'
export LOCATION=eastus
# Set this only after reviewing/approving the resource plan and charges.
export AZURE_COST_APPROVED=yes
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
~~~

Register the resource providers required by this project if your subscription does not already have them registered. This is an administrator setup action. Read the actual what-if before creating resources.


## Resource plan

AKS Free control plane / one Standard_D2s_v5 node, Basic ACR, SQL Basic database, Azure Managed Redis Balanced_B0 with high availability disabled, private LRS Blob Storage, three private endpoints and private DNS zones, a workload identity, internal Load Balancer/Private Link Service and Front Door **Premium** with WAF. This is the most expensive project in the set. Check regional availability for Managed Redis and Front Door Private Link before deployment. Do not assume a free-tier credit covers this stack.

## 1. Provision the cluster and private data tier

~~~bash
export AKS_ADMIN_GROUP_ID='<existing-entra-admin-group-object-id>'
read -rsp 'SQL bootstrap password: ' SQL_PASSWORD; echo
export SQL_PASSWORD
bash scripts/deploy-infra.sh
~~~

For a what-if first, create the dedicated resource group and use the same main.bicep parameters, supplying sqlPassword through a protected parameters file as the helper does. Do not place passwords in committed parameter files or command history.

The foundation creates the schema's infrastructure, not its tables. SQL and Redis use TLS and private endpoints. Blob uses the AKS service account's federated workload identity; no Storage account key is needed.

## 2. First release and bootstrap

Run from a Docker-capable, approved administrator shell. Keep SQL_PASSWORD exported from step 1. The script builds the image, applies the ServiceAccount/deployment, creates commerce-config if missing, runs an idempotent schema/catalog/artwork bootstrap Job, and waits for readiness.

~~~bash
export IMAGE_TAG=$(git rev-parse HEAD)
bash scripts/release.sh
unset SQL_PASSWORD
~~~

The bootstrap uses the SQL administrator for this learning environment. SQL credentials and the Redis access key are stored in a Kubernetes Secret, never in Git. Before production, move secret delivery to Key Vault/CSI, use a dedicated SQL runtime user or Entra identity with minimal permissions, and separate the migration identity from the application. The application currently retains Blob contributor permission for repeatable image seeding; reduce runtime access to Blob Data Reader after separating bootstrap.

## 3. Attach Front Door

Use a separate AKS context as described in the API project (az aks get-credentials followed by kubelogin convert-kubeconfig -l azurecli). Confirm commerce has a private load-balancer IP. Then:

~~~bash
bash scripts/deploy-edge.sh
~~~

Inspect and approve the single pending connection from this Front Door profile on **commerce-pls** in the AKS node resource group. Do not approve unrelated connection requests. If your tenant requires Private Link Service visibility configuration for Front Door's managed subscription, follow the Microsoft private-origin guide linked in REFERENCES.md and keep connection approval manual.

## 4. Prove it works

1. Open the printed Front Door HTTPS URL and load the catalog and all four product images.
2. Add two lamps; demo checkout must total $98.00. Send the same Idempotency-Key twice; SQL must contain one order.
3. Restart an application pod; orders must remain in SQL. Local-memory mode does not have this property.
4. Temporarily make Redis unavailable in a disposable test environment; catalog should still work from SQL.
5. Verify SQL, Redis and Blob hostnames resolve privately from a pod; public access must be disabled.
6. Verify the origin has only an internal load balancer, WAF is Prevention, and Front Door routes do not cache API responses.

Front Door uses HTTPS for the browser, and HTTP over Private Link to the internal app origin. This is private routing, **not end-to-end TLS**. Add a TLS-capable gateway and trusted origin certificate before using real customer data. No payment functionality is implemented.

## GitHub Actions release identity

After initial infrastructure/bootstrap succeeds, create or select an approved Entra application or managed identity for deployment. Configure a federated credential with issuer **https://token.actions.githubusercontent.com**, audience **api://AzureADTokenExchange**, and subject **repo:vasum-111/REPOSITORY:environment:azure-production** (replace REPOSITORY with this repo name). Do not create a long-lived client secret.

Create a GitHub environment named **azure-production**, limit deployments to main, and add a required reviewer where the account supports it. Set environment variables AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID and RESOURCE_GROUP. The release identity needs Reader on the project resource group (deployment outputs), AcrPush on the registry, AKS Cluster User Role on the cluster, and Azure Kubernetes Service RBAC Writer scoped to the portfolio namespace. A cluster administrator must create that namespace and its policy/ServiceAccount first. Bootstrap jobs need access to the existing commerce-config Secret in the commerce project. If applying cluster-scoped namespace manifests, that action stays with the administrator; the release script checks for the existing namespace.

Run **Deploy approved Azure release** from main and type DEPLOY. It runs tests, exchanges an OIDC token, builds/pushes the image and waits for rollout. Infrastructure creation is intentionally a separate operator step. A successful workflow is not a substitute for endpoint smoke testing.

