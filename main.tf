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
