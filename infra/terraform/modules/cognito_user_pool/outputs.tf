output "user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.this.arn
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.app_client.id
}

output "user_pool_client_secret" {
  value       = aws_cognito_user_pool_client.app_client.client_secret
  description = "Client secret (empty if generate_secret=false)"
  sensitive   = true
}

output "groups" {
  value = [
    aws_cognito_user_group.clinic_admin.name,
    aws_cognito_user_group.clinician.name,
    aws_cognito_user_group.patient.name,
  ]
}
