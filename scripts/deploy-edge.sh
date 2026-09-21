#!/usr/bin/env bash
set -euo pipefail
[[ "${AZURE_COST_APPROVED:-}" == yes ]] || { echo 'Approve Front Door Premium charges first.' >&2; exit 2; }
: "${RESOURCE_GROUP:?Set resource group}"
: "${AZURE_SUBSCRIPTION_ID:?Set approved subscription}"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
AKS=$(az deployment group show -g "$RESOURCE_GROUP" -n foundation --query properties.outputs.aksName.value -o tsv)
NODE_RG=$(az aks show -g "$RESOURCE_GROUP" -n "$AKS" --query nodeResourceGroup -o tsv)
PLS_ID=$(az network private-link-service show -g "$NODE_RG" -n commerce-pls --query id -o tsv)
ORIGIN=$(kubectl -n portfolio get svc commerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
[[ -n "$ORIGIN" ]] || { echo 'Wait for the internal load balancer IP.' >&2; exit 1; }
az deployment group create -g "$RESOURCE_GROUP" -n edge -f infra/edge.bicep -p prefix=commerce originHost="$ORIGIN" privateLinkId="$PLS_ID" >/dev/null
echo 'Approve only the pending Front Door connection on commerce-pls in the AKS node resource group.'
az deployment group show -g "$RESOURCE_GROUP" -n edge --query properties.outputs.url.value -o tsv
