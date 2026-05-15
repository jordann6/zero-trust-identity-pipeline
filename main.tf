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
