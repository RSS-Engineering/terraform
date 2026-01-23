# Optional monitoring configuration for connectivity_check module
# Enables scheduled checks with Datadog metrics

# EventBridge schedule for periodic monitoring
resource "aws_cloudwatch_event_rule" "monitoring_schedule" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "${var.function_name}-schedule"
  description         = "Run connectivity checks on schedule"
  schedule_expression = var.monitoring_schedule
  tags = {
    connectivity_check         = "true"
    connectivity_check_version = "v1"
  }
}

resource "aws_cloudwatch_event_target" "monitoring" {
  count = var.enable_monitoring ? 1 : 0
  rule  = aws_cloudwatch_event_rule.monitoring_schedule[0].name
  arn   = module.lambda.lambda_function_arn
  input = jsonencode({
    targets = var.monitoring_targets
  })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_monitoring ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monitoring_schedule[0].arn
}
