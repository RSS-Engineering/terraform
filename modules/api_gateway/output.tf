output "api_id" {
  value = aws_api_gateway_rest_api.rest_api.id
}

output "hostname" {
  value = "${aws_api_gateway_rest_api.rest_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
}

output "stage_url" {
  value = aws_api_gateway_stage.stage.invoke_url
}

output "log_role_arn" {
  value = var.apigateway_cloudwatch_role_arn != "" ? var.apigateway_cloudwatch_role_arn : aws_iam_role.log_role[0].arn
}
