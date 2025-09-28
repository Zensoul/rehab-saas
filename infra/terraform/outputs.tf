output "bucket_arn" {
  value       = module.raw_bucket.bucket_arn
  description = "S3 bucket ARN"
}

output "bucket_id" {
  value       = module.raw_bucket.bucket_id
  description = "S3 bucket name"
}

output "kms_key_arn" {
  value       = module.raw_bucket.kms_key_arn
  description = "KMS key ARN for raw bucket"
}

output "kms_key_id" {
  value       = module.raw_bucket.kms_key_id
  description = "KMS key id"
}

output "intakes_table_name" {
  value       = module.intakes_table.table_name
  description = "DynamoDB intakes table name"
}

output "intakes_table_arn" {
  value       = module.intakes_table.table_arn
  description = "DynamoDB intakes table ARN"
}

output "lambda_exec_role_arn" {
  value       = module.lambda_exec_role.role_arn
  description = "IAM role ARN for Lambda execution"
}

# HTTP API endpoint from lambda.tf stage
output "http_api_endpoint" {
  value       = aws_apigatewayv2_stage.default.invoke_url
  description = "HTTP API endpoint"
}
