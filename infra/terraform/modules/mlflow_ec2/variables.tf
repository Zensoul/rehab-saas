variable "env" { type = string }
variable "aws_region" { type = string }
variable "instance_type" { type = string default = "t3.small" }
variable "key_name" { type = string default = "" } # optional for SSH
variable "allowed_cidr" { type = string default = "0.0.0.0/0" } # tighten in prod
variable "bucket_name" { type = string }
variable "kms_key_arn" { type = string }
