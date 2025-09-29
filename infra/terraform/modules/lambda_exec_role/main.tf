########################
# Lambda exec role module
########################

# Assume role policy for Lambda service
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = merge({ Name = var.role_name, Environment = var.env }, var.tags)
}

# Attach CloudWatch Logs managed policy for Lambda logging
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Build inline least-privilege policy (DynamoDB + optional S3 + optional KMS + extra perms)
data "aws_iam_policy_document" "inline_policy" {
  # DynamoDB access scoped to the table and its indexes
  statement {
    sid     = "DynamoDBAccess"
    effect  = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:BatchWriteItem",
      "dynamodb:BatchGetItem"
    ]
    resources = compact([
      var.dynamodb_table_arn,
      tostring(var.dynamodb_table_arn) != "" ? "${var.dynamodb_table_arn}/index/*" : null
    ])
  }

  # S3 write for raw intake objects (bucket + objects)
  # only add this statement when both ARNs are provided
  dynamic "statement" {
    for_each = (var.raw_bucket_arn != "" && var.raw_bucket_objects_arn != "") ? [1] : []
    content {
      sid    = "AllowS3PutForRawIntakes"
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ]
      # ListBucket should reference the bucket ARN (not the objects ARN)
      resources = [
        var.raw_bucket_objects_arn,
        var.raw_bucket_arn
      ]
    }
  }

  # KMS access (Encrypt/Decrypt/GenerateDataKey) for optional kms_key_arn (if present)
  dynamic "statement" {
    for_each = var.kms_key_arn != "" ? [var.kms_key_arn] : []
    content {
      sid     = "KMSSymmetricAccess"
      effect  = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:ReEncrypt*",
        "kms:DescribeKey"
      ]
      resources = [statement.value]
    }
  }

  # Allow any extra permissions passed in var.extra_permissions
  # extra_permissions is expected to be a list of action strings, e.g. ["sqs:SendMessage","s3:ListBucket"]
  dynamic "statement" {
    for_each = var.extra_permissions
    content {
      sid     = "ExtraPerm${substr(md5(statement.value), 0, 8)}"
      effect  = "Allow"
      actions = [statement.value]
      resources = ["*"]
    }
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.role_name}-inline"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline_policy.json
}

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "role_name" {
  value = aws_iam_role.this.name
}

# Variables expected:
#
# variable "role_name" { type = string }
# variable "env" { type = string }
# variable "dynamodb_table_arn" { type = string }
# variable "kms_key_arn" { type = string, default = "" }
# variable "raw_bucket_arn" { type = string, default = "" }
# variable "raw_bucket_objects_arn" { type = string, default = "" }
# variable "extra_permissions" { type = list(string), default = [] }
# variable "tags" { type = map(string), default = {} }
