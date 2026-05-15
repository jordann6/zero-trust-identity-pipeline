#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating Phase 3 directory structure"
mkdir -p modules/key_vault

echo "==> Writing modules/key_vault/main.tf"
cat > modules/key_vault/main.tf << 'EOF'
data "azuread_service_principal" "terraform_sp" {
  client_id = var.terraform_client_id
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "kv_admin_terraform_sp" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azuread_service_principal.terraform_sp.object_id
}

resource "azurerm_role_assignment" "kv_secrets_user_managed_identity" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.managed_identity_principal_id
}

resource "azurerm_key_vault_secret" "demo" {
  name         = "demo-secret"
  value        = "zt-pipeline-demo-value-2026"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_admin_terraform_sp]
}

resource "azuread_application_federated_identity_credential" "github_actions" {
  application_id = var.app_registration_object_id
  display_name   = "github-actions-oidc"
  description    = "GitHub Actions OIDC for zero-trust-identity-pipeline"
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:jordann6/zero-trust-identity-pipeline:ref:refs/heads/main"
  audiences      = ["api://AzureADTokenExchange"]
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "kv-diagnostics"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
EOF

echo "==> Writing modules/key_vault/variables.tf"
cat > modules/key_vault/variables.tf << 'EOF'
variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "terraform_client_id" {
  type        = string
  description = "Client ID of the terraform-zt-pipeline app registration used to look up its service principal for RBAC"
}

variable "key_vault_name" {
  type        = string
  description = "Globally unique Key Vault name (3-24 chars, alphanumeric and hyphens)"
}

variable "log_analytics_workspace_name" {
  type    = string
  default = "zt-identity-law"
}

variable "managed_identity_principal_id" {
  type        = string
  description = "Principal ID of the workload managed identity from Phase 1"
}

variable "app_registration_object_id" {
  type        = string
  description = "Object ID of the zt-pipeline-app app registration from Phase 1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
EOF

echo "==> Writing modules/key_vault/outputs.tf"
cat > modules/key_vault/outputs.tf << 'EOF'
output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.main.name
}

output "federated_credential_id" {
  value = azuread_application_federated_identity_credential.github_actions.id
}
EOF

echo "==> Updating main.tf"
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

# module "conditional_access" {
#   source = "./modules/conditional_access"
#   trusted_ip_ranges    = var.trusted_ip_ranges
#   break_glass_user_ids = var.break_glass_user_ids
# }

module "key_vault" {
  source = "./modules/key_vault"

  resource_group_name           = var.resource_group_name
  location                      = var.location
  tenant_id                     = var.tenant_id
  terraform_client_id           = var.client_id
  key_vault_name                = var.key_vault_name
  log_analytics_workspace_name  = "zt-identity-law"
  managed_identity_principal_id = module.entra_identity.managed_identity_principal_id
  app_registration_object_id    = module.entra_identity.app_registration_object_id
  tags                          = var.tags
}

# Phase 4 - defender module goes here
# Phase 5 - sentinel module goes here
# Phase 6 - playbooks module goes here
# Phase 7 - monitoring module goes here
EOF

echo "==> Updating variables.tf"
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
  description = "Primary domain of the Entra ID tenant"
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique name for the demo storage account"
}

variable "key_vault_name" {
  type        = string
  description = "Globally unique Key Vault name (3-24 chars, alphanumeric and hyphens)"
}

variable "trusted_ip_ranges" {
  type        = list(string)
  description = "Trusted IP ranges in CIDR notation excluded from MFA policy"
  default     = ["0.0.0.0/32"]
}

variable "break_glass_user_ids" {
  type        = list(string)
  description = "Object IDs of break-glass accounts excluded from Conditional Access policies"
  default     = []
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

echo "==> Updating outputs.tf"
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

output "key_vault_id" {
  value = module.key_vault.key_vault_id
}

output "key_vault_uri" {
  value = module.key_vault.key_vault_uri
}

output "log_analytics_workspace_id" {
  value = module.key_vault.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  value = module.key_vault.log_analytics_workspace_name
}
EOF

echo "==> Verifying structure"
find . -not -path './.git*' -not -path './.terraform*' -type f | sort

echo "==> Phase 3 files written."
echo "    Add key_vault_name to terraform.tfvars before applying:"
echo '    key_vault_name = "zt-identity-kv-<suffix>"'
