#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating Phase 6 directory structure"
mkdir -p modules/playbooks

echo "==> Writing modules/playbooks/main.tf"
cat > modules/playbooks/main.tf << 'EOF'
resource "azurerm_logic_app_workflow" "incident_response" {
  name                = "zt-incident-response"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_logic_app_trigger_http_request" "sentinel_incident" {
  name         = "sentinel-incident-trigger"
  logic_app_id = azurerm_logic_app_workflow.incident_response.id

  schema = jsonencode({
    type = "object"
    properties = {
      incidentId  = { type = "string" }
      severity    = { type = "string" }
      title       = { type = "string" }
      status      = { type = "string" }
      description = { type = "string" }
    }
  })
}

resource "azurerm_logic_app_action_http" "notify_webhook" {
  name         = "notify-webhook"
  logic_app_id = azurerm_logic_app_workflow.incident_response.id
  method       = "POST"
  uri          = var.webhook_url

  body = jsonencode({
    text     = "Sentinel Incident Triggered"
    severity = "@{triggerBody()?['severity']}"
    title    = "@{triggerBody()?['title']}"
    incident = "@{triggerBody()?['incidentId']}"
  })

  headers = {
    "Content-Type" = "application/json"
  }

  depends_on = [azurerm_logic_app_trigger_http_request.sentinel_incident]
}

resource "azurerm_role_assignment" "sentinel_can_trigger_playbook" {
  scope                = azurerm_logic_app_workflow.incident_response.id
  role_definition_name = "Logic App Contributor"
  principal_id         = var.sentinel_service_principal_id
}

resource "azurerm_sentinel_automation_rule" "incident_response" {
  name                       = "11111111-1111-1111-1111-111111111111"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "ZT - Trigger Incident Response Playbook"
  order                      = 1
  enabled                    = true
  triggers_on                = "Incidents"
  triggers_when              = "Created"

  condition {
    property = "IncidentSeverity"
    operator = "Contains"
    values   = ["High", "Medium"]
  }

  action_playbook {
    logic_app_id = azurerm_logic_app_workflow.incident_response.id
    tenant_id    = var.tenant_id
    order        = 1
  }
}
EOF

echo "==> Writing modules/playbooks/variables.tf"
cat > modules/playbooks/variables.tf << 'EOF'
variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID where Sentinel is onboarded"
}

variable "sentinel_service_principal_id" {
  type        = string
  description = "Object ID of the Microsoft Sentinel service principal for RBAC on the Logic App"
}

variable "webhook_url" {
  type        = string
  description = "Webhook URL for the Logic App to POST incident alerts to (e.g. a webhook.site URL)"
}

variable "tags" {
  type    = map(string)
  default = {}
}
EOF

echo "==> Writing modules/playbooks/outputs.tf"
cat > modules/playbooks/outputs.tf << 'EOF'
output "logic_app_id" {
  value = azurerm_logic_app_workflow.incident_response.id
}

output "logic_app_name" {
  value = azurerm_logic_app_workflow.incident_response.name
}

output "logic_app_identity_principal_id" {
  value = azurerm_logic_app_workflow.incident_response.identity[0].principal_id
}

output "automation_rule_id" {
  value = azurerm_sentinel_automation_rule.incident_response.id
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

module "sentinel" {
  source = "./modules/sentinel"

  log_analytics_workspace_id = module.key_vault.log_analytics_workspace_id
}

module "playbooks" {
  source = "./modules/playbooks"

  resource_group_name           = var.resource_group_name
  location                      = var.location
  tenant_id                     = var.tenant_id
  log_analytics_workspace_id    = module.key_vault.log_analytics_workspace_id
  sentinel_service_principal_id = var.sentinel_service_principal_id
  webhook_url                   = var.webhook_url
  tags                          = var.tags
}

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

variable "sentinel_service_principal_id" {
  type        = string
  description = "Object ID of the Microsoft Sentinel service principal"
}

variable "webhook_url" {
  type        = string
  description = "Webhook URL for Logic App incident notifications"
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

output "sentinel_workspace_id" {
  value = module.sentinel.sentinel_workspace_id
}

output "logic_app_id" {
  value = module.playbooks.logic_app_id
}

output "logic_app_name" {
  value = module.playbooks.logic_app_name
}

output "automation_rule_id" {
  value = module.playbooks.automation_rule_id
}
EOF

echo "==> Verifying structure"
find . -not -path './.git*' -not -path './.terraform*' -type f | sort

echo "==> Phase 6 files written."
echo "    You need two values before applying:"
echo "    1. Sentinel service principal ID:"
echo "       az ad sp list --display-name 'Microsoft Sentinel' --query '[0].id' -o tsv"
echo "    2. A webhook URL from https://webhook.site"
