data "azurerm_client_config" "current" {}

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
  principal_id         = data.azurerm_client_config.current.object_id
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
  application_id = "/applications/${var.app_registration_object_id}"
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
