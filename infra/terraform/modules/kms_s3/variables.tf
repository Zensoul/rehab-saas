variable "env" {
  type        = string
  description = "Environment name (dev/stage/prod)"
}

variable "name_prefix" {
  type        = string
  description = "Name prefix for resources (short)"
  default     = "rehab"
}

variable "bucket_name" {
  type        = string
  description = "Optional explicit bucket name. If empty, module will construct one."
  default     = ""
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "kms_key_description" {
  type    = string
  default = "KMS key for encrypted S3 (raw data)"
}

variable "enable_key_rotation" {
  type    = bool
  default = true
}

variable "enable_versioning" {
  type    = bool
  default = true
}

variable "logs_prefix" {
  type    = string
  default = "logs/"
}

variable "logs_expiration_days" {
  type    = number
  default = 3650
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "prevent_destroy" {
  type        = bool
  description = "If true, prevent the S3 bucket from being destroyed by Terraform"
  default     = true
}


# Principals that should be explicitly allowed to manage/rotate the key (ARNs)
# e.g. ["arn:aws:iam::095289934056:role/GitHubActions-Terraform-Role"]
variable "admin_principals" {
  type    = list(string)
  default = []
}
