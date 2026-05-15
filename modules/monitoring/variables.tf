variable "resource_group_name" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address for monitoring alerts"
}

variable "webhook_url" {
  type        = string
  description = "Webhook URL for monitoring alert notifications"
}

variable "key_vault_id" {
  type        = string
  description = "Resource ID of the Key Vault to monitor"
}

variable "subscription_scope" {
  type        = string
  description = "Subscription resource ID used as scope for activity log alerts"
}

variable "tags" {
  type    = map(string)
  default = {}
}
