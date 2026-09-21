#!/usr/bin/env bash
set -euo pipefail
# Run once from an approved operator shell with a current AKS context.
: "${RESOURCE_GROUP:?Set the resource group}"
: "${SQL_PASSWORD:?Export the bootstrap SQL password}"
[[ "${AZURE_COST_APPROVED:-}" == yes ]] || exit 2
get_output() { az deployment group show -g "$RESOURCE_GROUP" -n foundation --query "properties.outputs.$1.value" -o tsv; }
export SQL_SERVER=$(get_output sqlHost)
export SQL_USER=portfolioadmin
export REDIS_HOST=$(get_output redisHost)
export STORAGE_ACCOUNT=$(get_output storageName)
REDIS_NAME=$(get_output redisName)
REDIS_ID=$(az resource show -g "$RESOURCE_GROUP" -n "$REDIS_NAME" --resource-type Microsoft.Cache/redisEnterprise --query id -o tsv)
export REDIS_PASSWORD=$(az rest --method post --url "https://management.azure.com$REDIS_ID/databases/default/listKeys?api-version=2025-07-01" --query primaryKey -o tsv)
SECRET_FILE=$(mktemp); chmod 600 "$SECRET_FILE"; trap 'rm -f "$SECRET_FILE"; unset REDIS_PASSWORD SQL_PASSWORD' EXIT
node --input-type=commonjs -e 'const fs=require("fs");const names=["SQL_SERVER","SQL_USER","SQL_PASSWORD","REDIS_HOST","REDIS_PASSWORD","STORAGE_ACCOUNT"];const data=Object.fromEntries(names.map(k=>[k,Buffer.from(process.env[k]).toString("base64")]));fs.writeFileSync(process.argv[1],JSON.stringify({apiVersion:"v1",kind:"Secret",metadata:{name:"commerce-config",namespace:"portfolio"},type:"Opaque",data}));' "$SECRET_FILE"
kubectl apply -f "$SECRET_FILE" >/dev/null
echo 'Data connection configuration saved to the portfolio namespace.'
