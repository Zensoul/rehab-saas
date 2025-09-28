############################################################
# Lambda + API Gateway - infra/terraform/lambda.tf
############################################################

# Deploy Lambda function (assumes zip is at infra/terraform/post_patient.zip)
resource "aws_lambda_function" "post_patient" {
  function_name = "rehab-post-patient-${var.env}"
  filename      = "${path.module}/post_patient.zip"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = module.lambda_exec_role.role_arn
  timeout       = 10
  publish       = true

  environment {
    variables = {
      INTAKES_TABLE = module.intakes_table.table_name
      RAW_BUCKET    = module.raw_bucket.bucket_id
      ENVIRONMENT   = var.env
      KMS_KEY_ARN   = module.raw_bucket.kms_key_arn
    }
  }

  tags = merge(var.tags, { Project = "rehab-saas" })
}

# Allow API Gateway to invoke the Lambda
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_patient.function_name
  principal     = "apigateway.amazonaws.com"
}

# Create an HTTP API (API Gateway v2)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "rehab-http-api-${var.env}"
  protocol_type = "HTTP"
}

# Integration
resource "aws_apigatewayv2_integration" "post_patient_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.post_patient.invoke_arn
  payload_format_version = "2.0"
}

# Route for POST /patients
resource "aws_apigatewayv2_route" "post_patient_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /patients"
  target    = "integrations/${aws_apigatewayv2_integration.post_patient_integration.id}"
}

# Stage (default)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Ensure permission properly references the API execution ARN
resource "aws_lambda_permission" "allow_http_api" {
  statement_id  = "AllowHttpApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_patient.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
