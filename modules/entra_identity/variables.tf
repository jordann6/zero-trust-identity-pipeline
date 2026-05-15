variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_domain" {
  type        = string
  description = "Primary domain of the Entra ID tenant (e.g. contoso.onmicrosoft.com)"
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique storage account name for the managed identity demo workload"
}

variable "managed_identity_name" {
  type    = string
  default = "zt-workload-identity"
}

variable "app_registration_name" {
  type    = string
  default = "zt-pipeline-app"
}

variable "security_group_name" {
  type    = string
  default = "zt-security-team"
}

variable "test_user_password" {
  type        = string
  sensitive   = true
  description = "Initial password for all test users. Must meet Entra ID complexity requirements."
  default     = "ZT-Lab-2026!"
}

variable "tags" {
  type    = map(string)
  default = {}
}
