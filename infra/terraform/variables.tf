variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region for resources"
}

variable "env" {
  type        = string
  default     = "dev"
  description = "Environment name (dev/stage/prod)"
}

variable "name_prefix" {
  type        = string
  default     = "rehab"
  description = "Name prefix for resources"
}

variable "tags" {
  type = map(string)
  default = {
    Owner = "zensoul"
  }
}

variable "kms_key_arn" {
  type        = string
  default     = ""
  description = "Optional KMS ARN to use for resources (can be empty to use AWS-managed keys)"
}
