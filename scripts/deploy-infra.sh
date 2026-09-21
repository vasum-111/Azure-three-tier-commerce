#!/usr/bin/env bash
set -euo pipefail
[[ "${AZURE_COST_APPROVED:-}" == "yes" ]] || { echo 'Stop: set AZURE_COST_APPROVED=yes only after approving the resource plan and Azure charges.' >&2; exit 2; }
: "${AZURE_SUBSCRIPTION_ID:?Set the approved Azure subscription ID}"
: "${RESOURCE_GROUP:?Set a dedicated portfolio resource group}"
LOCATION="${LOCATION:-eastus}"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

: "${AKS_ADMIN_GROUP_ID:?Set an existing Entra administrator group object ID}"
: "${SQL_PASSWORD:?Set a strong SQL bootstrap password; never commit it}"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" --tags project=azure-three-tier-commerce environment=portfolio >/dev/null
PARAMS=$(mktemp); chmod 600 "$PARAMS"; trap 'rm -f "$PARAMS"' EXIT
node -e 'require("fs").writeFileSync(process.argv[1],JSON.stringify({sqlPassword:{value:process.env.SQL_PASSWORD}}))' "$PARAMS"
az deployment group create -g "$RESOURCE_GROUP" -n foundation -f infra/main.bicep -p adminGroupId="$AKS_ADMIN_GROUP_ID" "@$PARAMS" >/dev/null
az deployment group show -g "$RESOURCE_GROUP" -n foundation --query properties.outputs -o json
