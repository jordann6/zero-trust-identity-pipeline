#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-zero-trust-identity-rg}"
WORKSPACE_NAME="${WORKSPACE_NAME:-zt-identity-law}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

check_env() {
  local missing=0
  for var in ARM_TENANT_ID ARM_SUBSCRIPTION_ID; do
    if [[ -z "${!var:-}" ]]; then
      echo "ERROR: $var is not set"
      missing=1
    fi
  done
  if [[ "$missing" -eq 1 ]]; then
    echo "Source your .env file and re-run."
    exit 1
  fi
}

wait_for_resource() {
  local resource_group="$1"
  local workspace="$2"
  local max_attempts=12
  local attempt=0

  echo "==> Waiting for Log Analytics workspace to be ready"
  until az monitor log-analytics workspace show \
    --resource-group "$resource_group" \
    --workspace-name "$workspace" \
    --query "provisioningState" -o tsv 2>/dev/null | grep -q "Succeeded"; do
    attempt=$((attempt + 1))
    if [[ "$attempt" -ge "$max_attempts" ]]; then
      echo "ERROR: Workspace did not reach Succeeded state after $max_attempts attempts"
      exit 1
    fi
    echo "  Attempt $attempt/$max_attempts - retrying in 15s"
    sleep 15
  done
  echo "  Workspace ready"
}

configure_pim() {
  echo "==> Configuring PIM eligible role assignments"

  if [[ ! -f "$SCRIPT_DIR/../pim-assignments.json" ]]; then
    echo "  WARNING: pim-assignments.json not found, skipping PIM setup"
    return
  fi

  local assignments count
  assignments=$(cat "$SCRIPT_DIR/../pim-assignments.json")
  count=$(echo "$assignments" | jq length)

  for i in $(seq 0 $((count - 1))); do
    local assignment principal_id scope role_definition_id request_id
    assignment=$(echo "$assignments" | jq ".[$i]")
    principal_id=$(echo "$assignment" | jq -r ".principalId")
    scope=$(echo "$assignment" | jq -r ".scope")
    role_definition_id=$(echo "$assignment" | jq -r ".roleDefinitionId")
    request_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)

    echo "  Assigning eligible role for principal $principal_id"

    az rest --method PUT \
      --uri "https://management.azure.com${scope}/providers/Microsoft.Authorization/roleEligibilityScheduleRequests/${request_id}?api-version=2020-10-01" \
      --body "{
        \"properties\": {
          \"principalId\": \"${principal_id}\",
          \"roleDefinitionId\": \"${role_definition_id}\",
          \"requestType\": \"AdminAssign\",
          \"scheduleInfo\": {
            \"expiration\": {
              \"type\": \"NoExpiration\"
            }
          },
          \"justification\": \"Zero Trust Identity Pipeline lab assignment\"
        }
      }" --output none

    echo "  Done: $principal_id"
  done
}

connect_sentinel() {
  echo "==> Connecting Sentinel data connectors"

  wait_for_resource "$RESOURCE_GROUP" "$WORKSPACE_NAME"

  echo "  Connecting Entra ID logs"
  az sentinel data-connector create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --data-connector-id "$(uuidgen)" \
    --kind AzureActiveDirectory \
    --tenant-id "$ARM_TENANT_ID" \
    --output none

  echo "  Connecting Azure Activity logs"
  az sentinel data-connector create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --data-connector-id "$(uuidgen)" \
    --kind AzureActivity \
    --subscription-id "$ARM_SUBSCRIPTION_ID" \
    --output none

  echo "  Connecting Defender for Cloud"
  az sentinel data-connector create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --data-connector-id "$(uuidgen)" \
    --kind AzureDefenderForCloud \
    --subscription-id "$ARM_SUBSCRIPTION_ID" \
    --output none

  echo "  Data connectors configured"
}

verify() {
  echo "==> Verifying bootstrap"

  echo "  Sentinel connectors:"
  az sentinel data-connector list \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --query "[].{Kind:kind, Name:name}" \
    --output table

  echo "  PIM eligible assignments:"
  az rest --method GET \
    --uri "https://management.azure.com/subscriptions/${ARM_SUBSCRIPTION_ID}/providers/Microsoft.Authorization/roleEligibilitySchedules?api-version=2020-10-01" \
    --query "value[].{Principal:properties.principalId, Role:properties.roleDefinitionId}" \
    --output table
}

main() {
  check_env
  configure_pim
  connect_sentinel
  verify
  echo "==> Bootstrap complete"
}

main "$@"
