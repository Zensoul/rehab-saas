variable "env" {
  type = string
}

variable "name_prefix" {
  type    = string
  default = "rehab"
}

variable "table_name" {
  type    = string
  default = "" # if empty : construct from prefix + env
}

variable "kms_key_arn" {
  type    = string
  default = "" # optional CMK for server-side encryption
}

variable "enable_pitr" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
