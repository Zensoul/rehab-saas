locals {
  pool_name   = "${var.name_prefix}-${var.env}-users"
  client_name = "${var.name_prefix}-${var.env}-app-client"
}

# Caller info and region for policy/resource construction
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# optional external id for SMS-role (recommended)
resource "random_string" "sms_external_id" {
  count   = var.enable_sms_mfa ? 1 : 0
  length  = 20
  special = false
}

# Optional IAM role Cognito will assume to publish SMS via SNS
resource "aws_iam_role" "cognito_sns_role" {
  count = var.enable_sms_mfa ? 1 : 0

  name = "${local.pool_name}-cognito-sns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowCognitoToAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cognito-idp.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = random_string.sms_external_id[0].result
          }
        }
      }
    ]
  })
}

# IAM policy for SNS publish (restrict to this account / region)
resource "aws_iam_role_policy" "cognito_sns_publish" {
  count = var.enable_sms_mfa ? 1 : 0
  role  = aws_iam_role.cognito_sns_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# The user pool
resource "aws_cognito_user_pool" "this" {
  name = local.pool_name

  # verify email by default
  auto_verified_attributes = ["email"]

  # password policy (reasonable secure defaults)
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # verification / invitation templates (customize if you use SES)
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Verify your ${local.pool_name} account"
    email_message        = "Your verification code is {####}"
    sms_message          = "Your verification code is {####}"
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
    # (unsupported attribute removed)
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # MFA & SMS configuration (conditional)
  mfa_configuration = var.mfa_configuration

  # TOTP software MFA
  software_token_mfa_configuration {
    enabled = var.enable_totp_mfa
  }

  # SMS configuration block requires sns_caller_arn and external_id if used
  dynamic "sms_configuration" {
    for_each = var.enable_sms_mfa ? [1] : []
    content {
      sns_caller_arn = aws_iam_role.cognito_sns_role[0].arn
      external_id    = random_string.sms_external_id[0].result
      sns_region     = data.aws_region.current.name
    }
  }

  tags = merge({
    Name        = local.pool_name
    Environment = var.env
  }, var.tags)
}

# Create 1 app client (no secret by default to simplify CLI tests)
resource "aws_cognito_user_pool_client" "app_client" {
  name         = local.client_name
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = var.generate_client_secret

  # explicit auth flows allowed for this client (use valid flow names)
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # prevent enumerating users (security hardening)
  prevent_user_existence_errors = "ENABLED"

  # security settings
  # refresh_token_validity is in days (integer)
  refresh_token_validity  = 30

  # NOTE: we do not set access_token_validity/id_token_validity explicitly to avoid provider-version mismatches.
  # Cognito defaults are sensible (typically 1 hour for access/id tokens).

  enable_token_revocation = true

  # fine tune: restrict allowed OAuth flows / callback_urls for hosted UI if you use it
  allowed_oauth_flows_user_pool_client = false

  # OAuth settings are left blank by default; add them via variables if you use hosted UI
  callback_urls = []
  logout_urls   = []

  depends_on = [aws_cognito_user_pool.this]
}

# Create standard groups
resource "aws_cognito_user_group" "clinic_admin" {
  name         = "clinic-admin"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Administrators for a clinic"
  precedence   = 1
}

resource "aws_cognito_user_group" "clinician" {
  name         = "clinician"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Clinician role (do not create full admin privileges)"
  precedence   = 10
}

resource "aws_cognito_user_group" "patient" {
  name         = "patient"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Patient role"
  precedence   = 100
}
