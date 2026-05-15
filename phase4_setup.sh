#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating Phase 4 directory structure"
mkdir -p modules/defender

echo "==> Writing modules/defender/main.tf"
cat > modules/defender/main.tf << 'EOF'
resource "azurerm_security_center_subscription_pricing" "key_vault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "arm" {
  tier          = "Standard"
  resource_type = "Arm"
}

resource "azurerm_security_center_contact" "main" {
  name  = "security-contact"
  email = var.security_contact_email

  alert_notifications = true
  alerts_to_admins    = true
}

resource "azurerm_security_center_workspace" "main" {
  scope        = "/subscriptions/${var.subscription_id}"
  workspace_id = var.log_analytics_workspace_id
}
EOF

echo "==> Writing modules/defender/variables.tf"
cat > modules/defender/variables.tf << 'EOF'
variable "subscription_id" {
  type = string
}

variable "security_contact_email" {
  type        = string
  description = "Email address for Defender for Cloud security alerts"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID to export Defender findings to"
}
EOF

echo "==> Writing modules/defender/outputs.tf"
cat > modules/defender/outputs.tf << 'EOF'
output "key_vault_defender_tier" {
  value = azurerm_security_center_subscription_pricing.key_vault.tier
}

output "storage_defender_tier" {
  value = azurerm_security_center_subscription_pricing.storage.tier
}

output "arm_defender_tier" {
  value = azurerm_security_center_subscription_pricing.arm.tier
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

module "defender" {
  source = "./modules/defender"

  subscription_id            = var.subscription_id
  security_contact_email     = var.security_contact_email
  log_analytics_workspace_id = module.key_vault.log_analytics_workspace_id
}

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

variable "security_contact_email" {
  type        = string
  description = "Email address for Defender for Cloud security alerts"
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

output "key_vault_defender_tier" {
  value = module.defender.key_vault_defender_tier
}

output "storage_defender_tier" {
  value = module.defender.storage_defender_tier
}
EOF

echo "==> Verifying structure"
find . -not -path './.git*' -not -path './.terraform*' -type f | sort

echo "==> Phase 4 files written."
echo "    Add security_contact_email to terraform.tfvars before applying:"
echo '    security_contact_email = "jordandn6@outlook.com"'
