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
