# infra/terraform/modules/kms_s3/main.tf
data "aws_caller_identity" "current" {}

locals {
  constructed_bucket = var.bucket_name != "" ? var.bucket_name : "${var.name_prefix}-${var.env}-raw-${substr(md5(timestamp()), 0, 6)}"
  account_id         = data.aws_caller_identity.current.account_id
}

# KMS key policy document: allow account root full control + allow S3 service to use key for encryption via s3.<region>.amazonaws.com
data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "AllowAccountFullAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # allow S3 service to use the key for encryption/decryption when proxying requests from S3 in this region
  statement {
    sid    = "AllowS3UseOfKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.region}.amazonaws.com"]
    }
  }

  # additional admin principals (optional)
  dynamic "statement" {
    for_each = var.admin_principals
    content {
      sid    = "AllowAdminPrincipal-${replace(statement.value, "/", "-")}"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = [statement.value]
      }
      actions   = ["kms:*"]
      resources = ["*"]
    }
  }
}

resource "aws_kms_key" "this" {
  description         = var.kms_key_description
  enable_key_rotation = var.enable_key_rotation
  policy              = data.aws_iam_policy_document.kms_key_policy.json
  tags                = merge({ Name = "${var.name_prefix}-${var.env}-kms" }, var.tags)
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name_prefix}-${var.env}-kms"
  target_key_id = aws_kms_key.this.key_id
}

#
# S3 bucket
#
resource "aws_s3_bucket" "this" {
  bucket = local.constructed_bucket
  acl    = "private"

  tags = merge({
    Name        = local.constructed_bucket
    Environment = var.env
  }, var.tags)

  # Prevent accidental destroy (literal boolean required by Terraform)
  lifecycle {
    prevent_destroy = true
  }
}

# New: versioning resource (replacement for deprecated versioning block)
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# New: lifecycle configuration resource for logs retention (replacement for lifecycle_rule)
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "logs-retention"
    status = "Enabled"

    filter {
      prefix = var.logs_prefix
    }

    expiration {
      days = var.logs_expiration_days
    }

    # optional transition example (commented)
    # transition {
    #   days          = 90
    #   storage_class = "STANDARD_IA"
    # }
  }
}

# Block public access on the bucket (recommended)
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce server-side encryption on the bucket using the created KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

# Bucket policy: deny PUT without server-side-encryption header using this KMS key
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "DenyUnEncryptedObjectUploads"
    effect  = "Deny"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [
      "${aws_s3_bucket.this.arn}/*"
    ]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}
