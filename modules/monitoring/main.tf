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
  location            = "global"
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
  location            = "global"
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
  location            = "global"
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

resource "azurerm_monitor_activity_log_alert" "policy_assignment_change" {
  location            = "global"
  name                = "zt-policy-assignment-change"
  resource_group_name = var.resource_group_name
  scopes              = [var.subscription_scope]
  description         = "An Azure Policy assignment was created or deleted"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Authorization/policyAssignments/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.security_alerts.id
  }
}
