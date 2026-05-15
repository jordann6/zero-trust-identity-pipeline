#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating Phase 7 directory structure"
mkdir -p modules/monitoring

echo "==> Writing modules/monitoring/main.tf"
cat > modules/monitoring/main.tf << 'EOF'
resource "azurerm_monitor_action_group" "security_alerts" {
  name                = "zt-security-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "zt-sec"
  tags                = var.tags

  email_receiver {
    name                    = "security-contact"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  webhook_receiver {
    name                    = "incident-webhook"
    service_uri             = var.webhook_url
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "key_vault_throttling" {
  name                = "zt-kv-throttling"
  resource_group_name = var.resource_group_name
  scopes              = [var.key_vault_id]
  description         = "Key Vault API requests are being throttled"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.KeyVault/vaults"
    metric_name      = "ServiceApiResult"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 50

    dimension {
      name     = "StatusCodeClass"
      operator = "Include"
      values   = ["4xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.security_alerts.id
  }
}

resource "azurerm_monitor_activity_log_alert" "role_assignment_change" {
  name                = "zt-role-assignment-change"
  resource_group_name = var.resource_group_name
  scopes              = [var.subscription_scope]
  description         = "A role assignment was created or deleted"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Authorization/roleAssignments/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.security_alerts.id
  }
}

resource "azurerm_monitor_activity_log_alert" "key_vault_delete" {
  name                = "zt-key-vault-delete"
  resource_group_name = var.resource_group_name
  scopes              = [var.subscription_scope]
  description         = "A Key Vault deletion was attempted"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.KeyVault/vaults/delete"
  }

  action {
    action_group_id = azurerm_monitor_action_group.security_alerts.id
  }
}

resource "azurerm_monitor_activity_log_alert" "security_policy_change" {
  name                = "zt-security-policy-change"
  resource_group_name = var.resource_group_name
  scopes              = [var.subscription_scope]
  description         = "A Defender for Cloud security policy was modified"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Security/policies/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.security_alerts.id
  }
}

resource "azurerm_monitor_activity_log_alert" "user_deletion" {
  name                = "zt-user-deletion"
  resource_group_name = var.resource_group_name
  scopes              = [var.subscription_scope]
  description         = "An Entra ID user was deleted"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.DirectoryServices/users/delete"
  }

  action {
    action_group_id = azurerm_monitor_action_group.security_alerts.id
  }
}
EOF

echo "==> Writing modules/monitoring/variables.tf"
cat > modules/monitoring/variables.tf << 'EOF'
variable "resource_group_name" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address for monitoring alerts"
}

variable "webhook_url" {
  type        = string
  description = "Webhook URL for monitoring alert notifications"
}

variable "key_vault_id" {
  type        = string
  description = "Resource ID of the Key Vault to monitor"
}

variable "subscription_scope" {
  type        = string
  description = "Subscription resource ID used as scope for activity log alerts"
}

variable "tags" {
  type    = map(string)
  default = {}
}
EOF

echo "==> Writing modules/monitoring/outputs.tf"
cat > modules/monitoring/outputs.tf << 'EOF'
output "action_group_id" {
  value = azurerm_monitor_action_group.security_alerts.id
}

output "action_group_name" {
  value = azurerm_monitor_action_group.security_alerts.name
}

output "alert_kv_throttling_id" {
  value = azurerm_monitor_metric_alert.key_vault_throttling.id
}

output "alert_role_assignment_change_id" {
  value = azurerm_monitor_activity_log_alert.role_assignment_change.id
}

output "alert_key_vault_delete_id" {
  value = azurerm_monitor_activity_log_alert.key_vault_delete.id
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

module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = var.resource_group_name
  alert_email         = var.security_contact_email
  webhook_url         = var.webhook_url
  key_vault_id        = module.key_vault.key_vault_id
  subscription_scope  = "/subscriptions/${var.subscription_id}"
  tags                = var.tags
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

output "action_group_id" {
  value = module.monitoring.action_group_id
}

output "action_group_name" {
  value = module.monitoring.action_group_name
}
EOF

echo "==> Verifying structure"
find . -not -path './.git*' -not -path './.terraform*' -type f | sort

echo "==> Phase 7 files written. Run terraform init -upgrade && terraform apply -auto-approve"
