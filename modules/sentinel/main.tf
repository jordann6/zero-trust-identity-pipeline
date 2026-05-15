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
  techniques                 = ["T1078"]

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
  techniques                 = ["T1552"]

  query = <<-KQL
    let known_ips = AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where TimeGenerated between (ago(30d) .. ago(1d))
    | where ResultSignature == "OK"
    | extend CallerUPN = tostring(split(requestUri_s, "/")[2])
    | summarize KnownIPs = make_set(CallerIPAddress) by CallerUPN;
    AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where TimeGenerated > ago(1d)
    | where OperationName in ("SecretGet", "KeyGet", "CertificateGet")
    | extend CallerUPN = tostring(split(requestUri_s, "/")[2])
    | join kind=leftouter known_ips on CallerUPN
    | where isnotempty(CallerIPAddress)
    | where not(set_has_element(KnownIPs, CallerIPAddress))
    | project TimeGenerated, Resource, OperationName, CallerIPAddress, CallerUPN
    | extend AccountCustomEntity = CallerUPN, IPCustomEntity = CallerIPAddress
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
