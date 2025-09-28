variable "env" {
  type    = string
  default = "dev"
}

variable "name_prefix" {
  type    = string
  default = "rehab"
}

variable "enable_sms_mfa" {
  description = "If true, create an IAM role and wire SMS for MFA. Note: SMS requires SNS setup / phone registration in some regions."
  type        = bool
  default     = false
}

variable "enable_totp_mfa" {
  description = "Enable software TOTP MFA (recommended)."
  type        = bool
  default     = true
}

variable "mfa_configuration" {
  description = "Cognito mfa_configuration (OFF | OPTIONAL | ON). Set ON to require MFA for sign-in."
  type        = string
  default     = "OPTIONAL"
}

variable "generate_client_secret" {
  description = "Whether the app client should have a client secret. Set false for easier CLI testing."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
