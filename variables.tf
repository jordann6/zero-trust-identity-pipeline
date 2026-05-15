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

variable "tags" {
  type = map(string)
  default = {
    project     = "zero-trust-identity-pipeline"
    environment = "lab"
    managed_by  = "terraform"
  }
}
