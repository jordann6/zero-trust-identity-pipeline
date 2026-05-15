resource "azuread_named_location" "trusted_ips" {
  display_name = "Trusted IP Ranges"

  ip {
    ip_ranges = var.trusted_ip_ranges
    trusted   = true
  }
}

resource "azuread_conditional_access_policy" "require_mfa" {
  display_name = "ZT - Require MFA for All Users"
  state        = "disabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = var.break_glass_user_ids
    }

    locations {
      included_locations = ["All"]
      excluded_locations = [azuread_named_location.trusted_ips.id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "ZT - Block Legacy Authentication"
  state        = "disabled"

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

resource "azuread_conditional_access_policy" "require_compliant_device" {
  display_name = "ZT - Require Compliant or Hybrid Joined Device"
  state        = "disabled"

  conditions {
    client_app_types = ["browser", "mobileAppsAndDesktopClients"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = var.break_glass_user_ids
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["compliantDevice", "domainJoinedDevice"]
  }
}

resource "azuread_conditional_access_policy" "block_high_risk_signin" {
  display_name = "ZT - Block High and Medium Risk Sign-ins"
  state        = "disabled"

  conditions {
    client_app_types    = ["all"]
    sign_in_risk_levels = ["high", "medium"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = var.break_glass_user_ids
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

resource "azuread_conditional_access_policy" "block_high_risk_user" {
  display_name = "ZT - Block High Risk Users"
  state        = "disabled"

  conditions {
    client_app_types = ["all"]
    user_risk_levels = ["high"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = var.break_glass_user_ids
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}
