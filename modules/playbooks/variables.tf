variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID where Sentinel is onboarded"
}

variable "sentinel_service_principal_id" {
  type        = string
  description = "Object ID of the Microsoft Sentinel service principal for RBAC on the Logic App"
}

variable "webhook_url" {
  type        = string
  description = "Webhook URL for the Logic App to POST incident alerts to (e.g. a webhook.site URL)"
}

variable "tags" {
  type    = map(string)
  default = {}
}
