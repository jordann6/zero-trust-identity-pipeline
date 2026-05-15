output "logic_app_id" {
  value = azurerm_logic_app_workflow.incident_response.id
}

output "logic_app_name" {
  value = azurerm_logic_app_workflow.incident_response.name
}

output "logic_app_identity_principal_id" {
  value = azurerm_logic_app_workflow.incident_response.identity[0].principal_id
}
