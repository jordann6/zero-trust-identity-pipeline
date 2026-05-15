variable "trusted_ip_ranges" {
  type        = list(string)
  description = "Trusted IP ranges in CIDR notation excluded from MFA policy"
}

variable "break_glass_user_ids" {
  type        = list(string)
  description = "Object IDs of break-glass accounts excluded from all Conditional Access policies"
  default     = []
}
