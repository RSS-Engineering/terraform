output "function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.lambda_function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.lambda_function_arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = module.lambda.lambda_function_invoke_arn
}

output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = module.lambda.lambda_cloudwatch_log_group_name
}
