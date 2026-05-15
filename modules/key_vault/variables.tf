variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "terraform_client_id" {
  type        = string
  description = "Client ID of the terraform-zt-pipeline app registration used to look up its service principal for RBAC"
}

variable "key_vault_name" {
  type        = string
  description = "Globally unique Key Vault name (3-24 chars, alphanumeric and hyphens)"
}

variable "log_analytics_workspace_name" {
  type    = string
  default = "zt-identity-law"
}

variable "managed_identity_principal_id" {
  type        = string
  description = "Principal ID of the workload managed identity from Phase 1"
}

variable "app_registration_object_id" {
  type        = string
  description = "Object ID of the zt-pipeline-app app registration from Phase 1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
