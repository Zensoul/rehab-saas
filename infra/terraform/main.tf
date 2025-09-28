############################################################
# Root Terraform - infra/terraform/main.tf (modules only)
############################################################

module "raw_bucket" {
  source               = "./modules/kms_s3"
  env                  = var.env
  name_prefix          = var.name_prefix
  bucket_name          = "rehab-dev-raw-566807"
  region               = var.aws_region
  logs_prefix          = "access-logs/"
  logs_expiration_days = 3650
  enable_key_rotation  = true
  enable_versioning    = true
  prevent_destroy      = true
  tags = merge(var.tags, {
    Owner   = "zensoul"
    Project = "rehab-saas"
  })
}

module "intakes_table" {
  source      = "./modules/dynamodb_table"
  env         = var.env
  name_prefix = var.name_prefix
  table_name  = "${var.name_prefix}-${var.env}-intakes"
  kms_key_arn = module.raw_bucket.kms_key_arn != "" ? module.raw_bucket.kms_key_arn : var.kms_key_arn
  enable_pitr = true
  tags        = merge(var.tags, { Project = "rehab-saas" })
}

module "lambda_exec_role" {
  source             = "./modules/lambda_exec_role"
  role_name          = "rehab-intake-lambda-exec-${var.env}"
  env                = var.env
  dynamodb_table_arn = module.intakes_table.table_arn
  kms_key_arn        = module.raw_bucket.kms_key_arn != "" ? module.raw_bucket.kms_key_arn : var.kms_key_arn

  raw_bucket_arn         = module.raw_bucket.bucket_arn
  raw_bucket_objects_arn = "${module.raw_bucket.bucket_arn}/*"

  tags = merge(var.tags, { Project = "rehab-saas" })
}

module "cognito" {
  source = "./modules/cognito_user_pool"

  env                    = var.env
  name_prefix            = var.name_prefix
  enable_sms_mfa         = false
  enable_totp_mfa        = true
  mfa_configuration      = "OPTIONAL"
  generate_client_secret = false
  tags = {
    Project = "rehab-saas"
    Owner   = "zensoul"
  }
}

# (No Lambda/API Gateway resources here — those are in lambda.tf)
