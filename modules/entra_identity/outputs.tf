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
