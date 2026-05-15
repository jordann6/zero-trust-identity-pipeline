#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating Phase 5 directory structure"
mkdir -p modules/sentinel

echo "==> Writing modules/sentinel/main.tf"
cat > modules/sentinel/main.tf << 'EOF'
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "main" {
  workspace_id = var.log_analytics_workspace_id
}

resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
  name                       = "zt-brute-force-signin"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "ZT - Multiple Failed Sign-ins (Brute Force)"
  severity                   = "Medium"
  enabled                    = true
  query_frequency            = "PT10M"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["CredentialAccess"]
  techniques                 = ["T1110"]

  query = <<-KQL
    SigninLogs
    | where ResultType != "0"
    | where ResultType !in ("50074", "50076", "50079", "50158")
    | summarize
        FailedAttempts = count(),
        IPs = make_set(IPAddress),
        UserAgents = make_set(UserAgent)
        by UserPrincipalName, bin(TimeGenerated, 10m)
    | where FailedAttempts >= 10
    | extend AccountCustomEntity = UserPrincipalName
  KQL

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

resource "azurerm_sentinel_alert_rule_scheduled" "new_country_signin" {
  name                       = "zt-new-country-signin"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "ZT - Sign-in from New Country"
  severity                   = "Medium"
  enabled                    = true
  query_frequency            = "PT1H"
  query_period               = "P7D"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["InitialAccess"]
  techniques                 = ["T1078"]

  query = <<-KQL
    let known_countries = SigninLogs
    | where TimeGenerated between (ago(30d) .. ago(1d))
    | where ResultType == "0"
    | summarize KnownCountries = make_set(Location) by UserPrincipalName;
    SigninLogs
    | where TimeGenerated > ago(1d)
    | where ResultType == "0"
    | join kind=leftouter known_countries on UserPrincipalName
    | where isnotempty(Location)
    | where not(set_has_element(KnownCountries, Location))
    | project TimeGenerated, UserPrincipalName, Location, IPAddress, AppDisplayName
    | extend AccountCustomEntity = UserPrincipalName, IPCustomEntity = IPAddress
  KQL

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

resource "azurerm_sentinel_alert_rule_scheduled" "pim_outside_hours" {
  name                       = "zt-pim-activation-outside-hours"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "ZT - PIM Role Activation Outside Business Hours"
  severity                   = "Medium"
  enabled                    = true
  query_frequency            = "PT1H"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["PrivilegeEscalation"]
  techniques                 = ["T1078.004"]

  query = <<-KQL
    AuditLogs
    | where OperationName == "Add eligible member to role in PIM completed (permanent)"
        or OperationName == "Add member to role in PIM completed (timebound)"
    | extend Hour = hourofday(TimeGenerated)
    | where Hour < 7 or Hour > 19
    | extend
        InitiatedBy = tostring(InitiatedBy.user.userPrincipalName),
        TargetUser  = tostring(TargetResources[0].userPrincipalName),
        RoleName    = tostring(TargetResources[0].displayName)
    | project TimeGenerated, InitiatedBy, TargetUser, RoleName, Hour
    | extend AccountCustomEntity = InitiatedBy
  KQL

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

resource "azurerm_sentinel_alert_rule_scheduled" "key_vault_unusual_access" {
  name                       = "zt-key-vault-unusual-access"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "ZT - Key Vault Access from Unfamiliar IP"
  severity                   = "High"
  enabled                    = true
  query_frequency            = "PT1H"
  query_period               = "P7D"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["CredentialAccess"]
  techniques                 = ["T1552.001"]

  query = <<-KQL
    let known_ips = AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where TimeGenerated between (ago(30d) .. ago(1d))
    | where ResultSignature == "OK"
    | summarize KnownIPs = make_set(CallerIPAddress) by identity_claim_upn_s;
    AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where TimeGenerated > ago(1d)
    | where OperationName in ("SecretGet", "KeyGet", "CertificateGet")
    | join kind=leftouter known_ips on $left.identity_claim_upn_s == $right.identity_claim_upn_s
    | where isnotempty(CallerIPAddress)
    | where not(set_has_element(KnownIPs, CallerIPAddress))
    | project TimeGenerated, Resource, OperationName, CallerIPAddress, identity_claim_upn_s
    | extend AccountCustomEntity = identity_claim_upn_s, IPCustomEntity = CallerIPAddress
  KQL

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

resource "azurerm_sentinel_alert_rule_scheduled" "bulk_user_deletion" {
  name                       = "zt-bulk-user-deletion"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "ZT - Bulk User Deletion"
  severity                   = "High"
  enabled                    = true
  query_frequency            = "PT1H"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["Impact"]
  techniques                 = ["T1531"]

  query = <<-KQL
    AuditLogs
    | where OperationName == "Delete user"
    | where Result == "success"
    | extend InitiatedBy = tostring(InitiatedBy.user.userPrincipalName)
    | summarize DeletionCount = count(), DeletedUsers = make_set(tostring(TargetResources[0].userPrincipalName))
        by InitiatedBy, bin(TimeGenerated, 1h)
    | where DeletionCount >= 3
    | extend AccountCustomEntity = InitiatedBy
  KQL

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}
EOF

echo "==> Writing modules/sentinel/variables.tf"
cat > modules/sentinel/variables.tf << 'EOF'
variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID where Sentinel is onboarded"
}
EOF

echo "==> Writing modules/sentinel/outputs.tf"
cat > modules/sentinel/outputs.tf << 'EOF'
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
EOF

echo "==> Updating main.tf"
cat > main.tf << 'EOF'
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

# Phase 6 - playbooks module goes here
# Phase 7 - monitoring module goes here
EOF

echo "==> Updating outputs.tf"
cat > outputs.tf << 'EOF'
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

output "key_vault_defender_tier" {
  value = module.defender.key_vault_defender_tier
}

output "storage_defender_tier" {
  value = module.defender.storage_defender_tier
}

output "sentinel_workspace_id" {
  value = module.sentinel.sentinel_workspace_id
}
EOF

echo "==> Verifying structure"
find . -not -path './.git*' -not -path './.terraform*' -type f | sort

echo "==> Phase 5 files written. Run bootstrap.sh after terraform apply to connect data connectors."
