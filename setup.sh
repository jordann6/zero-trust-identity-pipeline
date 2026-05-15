#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating directory structure"
mkdir -p modules/entra_identity scripts

echo "==> Writing versions.tf"
cat > versions.tf << 'EOF'
terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"
    }
  }

  backend "s3" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azuread" {
  tenant_id     = var.tenant_id
  client_id     = var.client_id
  client_secret = var.client_secret
}
EOF

echo "==> Writing backend.hcl"
cat > backend.hcl << 'EOF'
bucket = "tf-backend-jord-projs"
key    = "zero-trust-identity/terraform.tfstate"
region = "us-east-1"
EOF

echo "==> Writing variables.tf"
cat > variables.tf << 'EOF'
variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "client_id" {
  type        = string
  description = "App registration client ID used by the azuread provider"
}

variable "client_secret" {
  type        = string
  sensitive   = true
  description = "App registration client secret used by the azuread provider"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Primary Azure region for all resources"
}

variable "resource_group_name" {
  type        = string
  default     = "zero-trust-identity-rg"
  description = "Name of the root resource group"
}

variable "tenant_domain" {
  type        = string
  description = "Primary domain of the Entra ID tenant (e.g. contoso.onmicrosoft.com)"
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique name for the demo storage account (3-24 chars, lowercase alphanumeric)"
}

variable "tags" {
  type = map(string)
  default = {
    project     = "zero-trust-identity-pipeline"
    environment = "lab"
    managed_by  = "terraform"
  }
}
EOF

echo "==> Writing main.tf"
cat > main.tf << 'EOF'
module "entra_identity" {
  source = "./modules/entra_identity"

  resource_group_name   = var.resource_group_name
  location              = var.location
  tenant_domain         = var.tenant_domain
  storage_account_name  = var.storage_account_name
  managed_identity_name = "zt-workload-identity"
  app_registration_name = "zt-pipeline-app"
  security_group_name   = "zt-security-team"
  tags                  = var.tags
}

# Phase 2 - conditional_access module goes here
# Phase 3 - key_vault module goes here
# Phase 4 - defender module goes here
# Phase 5 - sentinel module goes here
# Phase 6 - playbooks module goes here
# Phase 7 - monitoring module goes here
EOF

echo "==> Writing outputs.tf"
cat > outputs.tf << 'EOF'
output "resource_group_name" {
  value = module.entra_identity.resource_group_name
}

output "resource_group_id" {
  value = module.entra_identity.resource_group_id
}

output "managed_identity_client_id" {
  value = module.entra_identity.managed_identity_client_id
}

output "managed_identity_principal_id" {
  value = module.entra_identity.managed_identity_principal_id
}

output "app_registration_client_id" {
  value = module.entra_identity.app_registration_client_id
}

output "app_registration_object_id" {
  value = module.entra_identity.app_registration_object_id
}

output "storage_account_id" {
  value = module.entra_identity.storage_account_id
}

output "security_group_object_id" {
  value = module.entra_identity.security_group_object_id
}

output "test_user_object_ids" {
  value = module.entra_identity.test_user_object_ids
}
EOF

echo "==> Writing terraform.tfvars.example"
cat > terraform.tfvars.example << 'EOF'
tenant_id            = "<your-tenant-id>"
subscription_id      = "<your-subscription-id>"
client_id            = "<app-registration-client-id>"
client_secret        = "<app-registration-client-secret>"
tenant_domain        = "<your-tenant>.onmicrosoft.com"
storage_account_name = "ztidentitylab<suffix>"
location             = "eastus"
resource_group_name  = "zero-trust-identity-rg"
EOF

echo "==> Writing .gitignore"
cat > .gitignore << 'EOF'
.terraform/
.terraform.lock.hcl
terraform.tfvars
*.tfstate
*.tfstate.backup
.env
*.tfplan
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
pim-assignments.json
EOF

echo "==> Writing modules/entra_identity/main.tf"
cat > modules/entra_identity/main.tf << 'EOF'
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azuread_user" "admin" {
  user_principal_name   = "zt-admin@${var.tenant_domain}"
  display_name          = "ZT Pipeline Admin"
  mail_nickname         = "zt-admin"
  password              = var.test_user_password
  force_password_change = false
}

resource "azuread_user" "analyst" {
  user_principal_name   = "zt-analyst@${var.tenant_domain}"
  display_name          = "ZT Pipeline Analyst"
  mail_nickname         = "zt-analyst"
  password              = var.test_user_password
  force_password_change = false
}

resource "azuread_user" "reader" {
  user_principal_name   = "zt-reader@${var.tenant_domain}"
  display_name          = "ZT Pipeline Reader"
  mail_nickname         = "zt-reader"
  password              = var.test_user_password
  force_password_change = false
}

resource "azuread_group" "security_team" {
  display_name     = var.security_group_name
  security_enabled = true
  mail_enabled     = false

  members = [
    azuread_user.admin.object_id,
    azuread_user.analyst.object_id,
    azuread_user.reader.object_id,
  ]
}

resource "azuread_application" "app" {
  display_name = var.app_registration_name

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }

  web {
    implicit_grant {
      access_token_issuance_enabled  = false
      id_token_issuance_enabled      = false
    }
  }
}

resource "azuread_service_principal" "app" {
  client_id = azuread_application.app.client_id

  feature_tags {
    enterprise = true
  }
}

resource "azuread_application_password" "app" {
  application_id = azuread_application.app.id
  display_name   = "terraform-managed"
  end_date       = timeadd(timestamp(), "8760h")

  lifecycle {
    ignore_changes = [end_date]
  }
}

resource "azurerm_user_assigned_identity" "workload" {
  name                = var.managed_identity_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

resource "azurerm_storage_account" "demo" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  min_tls_version                 = "TLS1_2"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "identity_storage_reader" {
  scope                = azurerm_storage_account.demo.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_role_assignment" "admin_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_user.admin.object_id
}

resource "azurerm_role_assignment" "analyst_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azuread_user.analyst.object_id
}
EOF

echo "==> Writing modules/entra_identity/variables.tf"
cat > modules/entra_identity/variables.tf << 'EOF'
variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_domain" {
  type        = string
  description = "Primary domain of the Entra ID tenant (e.g. contoso.onmicrosoft.com)"
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique storage account name for the managed identity demo workload"
}

variable "managed_identity_name" {
  type    = string
  default = "zt-workload-identity"
}

variable "app_registration_name" {
  type    = string
  default = "zt-pipeline-app"
}

variable "security_group_name" {
  type    = string
  default = "zt-security-team"
}

variable "test_user_password" {
  type        = string
  sensitive   = true
  description = "Initial password for all test users. Must meet Entra ID complexity requirements."
  default     = "ZT-Lab-2026!"
}

variable "tags" {
  type    = map(string)
  default = {}
}
EOF

echo "==> Writing modules/entra_identity/outputs.tf"
cat > modules/entra_identity/outputs.tf << 'EOF'
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "resource_group_id" {
  value = azurerm_resource_group.main.id
}

output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.workload.client_id
}

output "managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.workload.principal_id
}

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.workload.id
}

output "app_registration_client_id" {
  value = azuread_application.app.client_id
}

output "app_registration_object_id" {
  value = azuread_application.app.object_id
}

output "app_client_secret" {
  value     = azuread_application_password.app.value
  sensitive = true
}

output "storage_account_id" {
  value = azurerm_storage_account.demo.id
}

output "storage_account_name" {
  value = azurerm_storage_account.demo.name
}

output "security_group_object_id" {
  value = azuread_group.security_team.object_id
}

output "test_user_object_ids" {
  value = {
    admin   = azuread_user.admin.object_id
    analyst = azuread_user.analyst.object_id
    reader  = azuread_user.reader.object_id
  }
}
EOF

echo "==> Writing pim-assignments.json"
cat > pim-assignments.json << 'EOF'
[
  {
    "description": "ZT Admin - eligible for Owner on resource group",
    "principalId": "<zt-admin-object-id>",
    "roleDefinitionId": "/subscriptions/<subscription-id>/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635",
    "scope": "/subscriptions/<subscription-id>/resourceGroups/zero-trust-identity-rg"
  },
  {
    "description": "ZT Analyst - eligible for Security Reader",
    "principalId": "<zt-analyst-object-id>",
    "roleDefinitionId": "/subscriptions/<subscription-id>/providers/Microsoft.Authorization/roleDefinitions/39bc4728-0917-49c7-9d2c-d95423bc2eb4",
    "scope": "/subscriptions/<subscription-id>/resourceGroups/zero-trust-identity-rg"
  }
]
EOF

echo "==> Writing scripts/bootstrap.sh"
cat > scripts/bootstrap.sh << 'EOF'
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
EOF

echo "==> Writing scripts/teardown.sh"
cat > scripts/teardown.sh << 'EOF'
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
EOF

chmod +x scripts/bootstrap.sh scripts/teardown.sh

echo "==> Verifying structure"
find . -not -path './.git*' -type f | sort

echo "==> Done. All files written."
