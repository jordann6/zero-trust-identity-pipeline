#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating Phase 2 directory structure"
mkdir -p modules/conditional_access

echo "==> Writing modules/conditional_access/main.tf"
cat > modules/conditional_access/main.tf << 'EOF'
resource "azuread_named_location" "trusted_ips" {
  display_name = "Trusted IP Ranges"

  ip {
    ip_ranges = var.trusted_ip_ranges
    trusted   = true
  }
}

resource "azuread_conditional_access_policy" "require_mfa" {
  display_name = "ZT - Require MFA for All Users"
  state        = "enabled"

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
  state        = "enabled"

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
  state        = "enabledForReportingButNotEnforced"

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
  state        = "enabledForReportingButNotEnforced"

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
  state        = "enabledForReportingButNotEnforced"

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
EOF

echo "==> Writing modules/conditional_access/variables.tf"
cat > modules/conditional_access/variables.tf << 'EOF'
variable "trusted_ip_ranges" {
  type        = list(string)
  description = "Trusted IP ranges in CIDR notation excluded from MFA policy"
}

variable "break_glass_user_ids" {
  type        = list(string)
  description = "Object IDs of break-glass accounts excluded from all Conditional Access policies"
  default     = []
}
EOF

echo "==> Writing modules/conditional_access/outputs.tf"
cat > modules/conditional_access/outputs.tf << 'EOF'
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

module "conditional_access" {
  source = "./modules/conditional_access"

  trusted_ip_ranges    = var.trusted_ip_ranges
  break_glass_user_ids = var.break_glass_user_ids
}

# Phase 3 - key_vault module goes here
# Phase 4 - defender module goes here
# Phase 5 - sentinel module goes here
# Phase 6 - playbooks module goes here
# Phase 7 - monitoring module goes here
EOF

echo "==> Updating variables.tf"
cat > variables.tf << 'EOF'
variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "client_id" {
  type        = string
  description = "App registration client ID used by the azuread provider"
}

variable "client_secret" {
  type        = string
  sensitive   = true
  description = "App registration client secret used by the azuread provider"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Primary Azure region for all resources"
}

variable "resource_group_name" {
  type        = string
  default     = "zero-trust-identity-rg"
  description = "Name of the root resource group"
}

variable "tenant_domain" {
  type        = string
  description = "Primary domain of the Entra ID tenant (e.g. contoso.onmicrosoft.com)"
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique name for the demo storage account (3-24 chars, lowercase alphanumeric)"
}

variable "trusted_ip_ranges" {
  type        = list(string)
  description = "Trusted IP ranges in CIDR notation excluded from MFA policy"
  default     = ["0.0.0.0/32"]
}

variable "break_glass_user_ids" {
  type        = list(string)
  description = "Object IDs of break-glass accounts excluded from all Conditional Access policies"
  default     = []
}

variable "tags" {
  type = map(string)
  default = {
    project     = "zero-trust-identity-pipeline"
    environment = "lab"
    managed_by  = "terraform"
  }
}
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

output "policy_require_mfa_id" {
  value = module.conditional_access.policy_require_mfa_id
}

output "policy_block_legacy_auth_id" {
  value = module.conditional_access.policy_block_legacy_auth_id
}
EOF

echo "==> Verifying structure"
find . -not -path './.git*' -not -path './.terraform*' -type f | sort

echo "==> Phase 2 files written. Add your home IP to terraform.tfvars before applying:"
echo "    trusted_ip_ranges = [\"<your-ip>/32\"]"
echo "    Run: curl -s https://api.ipify.org && echo"
