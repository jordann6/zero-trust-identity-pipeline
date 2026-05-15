resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azuread_user" "admin" {
  user_principal_name   = "zt-admin@${var.tenant_domain}"
  display_name          = "ZT Pipeline Admin"
  mail_nickname         = "zt-admin"
  password              = var.test_user_password
  force_password_change = false
}

resource "azuread_user" "analyst" {
  user_principal_name   = "zt-analyst@${var.tenant_domain}"
  display_name          = "ZT Pipeline Analyst"
  mail_nickname         = "zt-analyst"
  password              = var.test_user_password
  force_password_change = false
}

resource "azuread_user" "reader" {
  user_principal_name   = "zt-reader@${var.tenant_domain}"
  display_name          = "ZT Pipeline Reader"
  mail_nickname         = "zt-reader"
  password              = var.test_user_password
  force_password_change = false
}

resource "azuread_group" "security_team" {
  display_name     = var.security_group_name
  security_enabled = true
  mail_enabled     = false

  members = [
    azuread_user.admin.object_id,
    azuread_user.analyst.object_id,
    azuread_user.reader.object_id,
  ]
}

resource "azuread_application" "app" {
  display_name = var.app_registration_name

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }

  web {
    implicit_grant {
      access_token_issuance_enabled  = false
      id_token_issuance_enabled      = false
    }
  }
}

resource "azuread_service_principal" "app" {
  client_id = azuread_application.app.client_id

  feature_tags {
    enterprise = true
  }
}

resource "azuread_application_password" "app" {
  application_id = azuread_application.app.id
  display_name   = "terraform-managed"
  end_date       = timeadd(timestamp(), "8760h")

  lifecycle {
    ignore_changes = [end_date]
  }
}

resource "azurerm_user_assigned_identity" "workload" {
  name                = var.managed_identity_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

resource "azurerm_storage_account" "demo" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  min_tls_version                 = "TLS1_2"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "identity_storage_reader" {
  scope                = azurerm_storage_account.demo.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_role_assignment" "admin_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_user.admin.object_id
}

resource "azurerm_role_assignment" "analyst_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azuread_user.analyst.object_id
}
