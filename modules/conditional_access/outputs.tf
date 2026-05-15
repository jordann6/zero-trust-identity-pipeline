output "named_location_id" {
  value = azuread_named_location.trusted_ips.id
}

output "policy_require_mfa_id" {
  value = azuread_conditional_access_policy.require_mfa.id
}

output "policy_block_legacy_auth_id" {
  value = azuread_conditional_access_policy.block_legacy_auth.id
}

output "policy_require_compliant_device_id" {
  value = azuread_conditional_access_policy.require_compliant_device.id
}

output "policy_block_high_risk_signin_id" {
  value = azuread_conditional_access_policy.block_high_risk_signin.id
}

output "policy_block_high_risk_user_id" {
  value = azuread_conditional_access_policy.block_high_risk_user.id
}
