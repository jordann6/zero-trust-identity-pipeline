output "sentinel_workspace_id" {
  value = azurerm_sentinel_log_analytics_workspace_onboarding.main.workspace_id
}

output "rule_brute_force_id" {
  value = azurerm_sentinel_alert_rule_scheduled.brute_force.id
}

output "rule_new_country_signin_id" {
  value = azurerm_sentinel_alert_rule_scheduled.new_country_signin.id
}

output "rule_pim_outside_hours_id" {
  value = azurerm_sentinel_alert_rule_scheduled.pim_outside_hours.id
}

output "rule_key_vault_unusual_access_id" {
  value = azurerm_sentinel_alert_rule_scheduled.key_vault_unusual_access.id
}

output "rule_bulk_user_deletion_id" {
  value = azurerm_sentinel_alert_rule_scheduled.bulk_user_deletion.id
}
