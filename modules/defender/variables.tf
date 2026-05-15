variable "subscription_id" {
  type = string
}

variable "security_contact_email" {
  type        = string
  description = "Email address for Defender for Cloud security alerts"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID to export Defender findings to"
}
