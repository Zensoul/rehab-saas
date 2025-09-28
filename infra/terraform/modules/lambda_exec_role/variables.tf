variable "role_name" {
  type = string
}

variable "env" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "kms_key_arn" {
  type    = string
  default = ""
}

variable "extra_permissions" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

# raw bucket ARNs used to scope S3 permissions (passed in from root module)
variable "raw_bucket_arn" {
  description = "ARN of the raw S3 bucket (arn:aws:s3:::bucket-name)"
  type        = string
  default     = ""
}

variable "raw_bucket_objects_arn" {
  description = "ARN for objects in the raw S3 bucket (arn:aws:s3:::bucket-name/*)"
  type        = string
  default     = ""
}
