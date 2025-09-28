locals {
  name = var.table_name != "" ? var.table_name : "${var.name_prefix}-${var.env}-intakes"
}

resource "aws_dynamodb_table" "this" {
  name         = local.name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "intake_id"

  attribute {
    name = "intake_id"
    type = "S"
  }

  attribute {
    name = "tenant_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "tenant_status_idx"
    hash_key        = "tenant_id"
    range_key       = "status"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : null
  }

  tags = merge({
    Name        = local.name
    Environment = var.env
  }, var.tags)
}
