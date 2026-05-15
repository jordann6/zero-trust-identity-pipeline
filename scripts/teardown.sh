#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="zero-trust-identity-rg"
WORKSPACE_NAME="zt-identity-law"
TF_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Starting Zero Trust Identity Pipeline teardown"

echo "==> Disabling Sentinel automation rules"
az sentinel automation-rule list \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query "[].name" -o tsv 2>/dev/null | while read -r rule; do
    az sentinel automation-rule delete \
      --resource-group "$RESOURCE_GROUP" \
      --workspace-name "$WORKSPACE_NAME" \
      --automation-rule-name "$rule" \
      --yes
done

echo "==> Removing Sentinel data connectors"
az sentinel data-connector list \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query "[].name" -o tsv 2>/dev/null | while read -r connector; do
    az sentinel data-connector delete \
      --resource-group "$RESOURCE_GROUP" \
      --workspace-name "$WORKSPACE_NAME" \
      --data-connector-id "$connector" \
      --yes
done

echo "==> Disabling Defender for Cloud plans"
for plan in KeyVaults StorageAccounts VirtualMachines; do
  az security pricing create \
    --name "$plan" \
    --tier Free
done

echo "==> Purging soft-deleted Key Vault (if applicable)"
KV_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || true)
if [[ -n "$KV_NAME" ]]; then
  az keyvault delete --name "$KV_NAME" --resource-group "$RESOURCE_GROUP" || true
  az keyvault purge --name "$KV_NAME" --no-wait || true
fi

echo "==> Removing PIM eligible role assignments"
az rest --method GET \
  --uri "https://management.azure.com/providers/Microsoft.Authorization/roleEligibilitySchedules?api-version=2020-10-01&\$filter=asTarget()" \
  --query "value[].name" -o tsv | while read -r schedule; do
    az rest --method DELETE \
      --uri "https://management.azure.com/providers/Microsoft.Authorization/roleEligibilitySchedules/${schedule}?api-version=2020-10-01" || true
done

echo "==> Running terraform destroy"
cd "$TF_DIR"
terraform destroy -auto-approve

echo "==> Verifying resource group is gone"
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
  echo "  Resource group still exists, deleting directly"
  az group delete --name "$RESOURCE_GROUP" --yes --no-wait
else
  echo "  Resource group confirmed deleted"
fi

echo "==> Teardown complete"
