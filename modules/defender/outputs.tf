output "key_vault_defender_tier" {
  value = azurerm_security_center_subscription_pricing.key_vault.tier
}

output "storage_defender_tier" {
  value = azurerm_security_center_subscription_pricing.storage.tier
}

output "arm_defender_tier" {
  value = azurerm_security_center_subscription_pricing.arm.tier
}
