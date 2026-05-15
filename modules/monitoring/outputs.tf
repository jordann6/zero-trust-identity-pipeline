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
