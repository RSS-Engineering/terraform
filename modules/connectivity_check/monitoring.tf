# Optional monitoring configuration for connectivity_check module
# Enables scheduled checks and CloudWatch alarms

# EventBridge schedule for periodic monitoring
resource "aws_cloudwatch_event_rule" "monitoring_schedule" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "${var.function_name}-schedule"
  description         = "Run connectivity checks on schedule"
  schedule_expression = var.monitoring_schedule
  tags                = module.lambda.lambda_function_tags
}

resource "aws_cloudwatch_event_target" "monitoring" {
  count = var.enable_monitoring ? 1 : 0
  rule  = aws_cloudwatch_event_rule.monitoring_schedule[0].name
  arn   = module.lambda.lambda_function_arn
  input = jsonencode({
    targets             = var.monitoring_targets
    publishMetrics      = true
    cloudwatchNamespace = local.cloudwatch_namespace
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

# IAM policy for publishing CloudWatch metrics
resource "aws_iam_policy" "cloudwatch_metrics" {
  count       = var.enable_monitoring ? 1 : 0
  name        = "${var.function_name}-cloudwatch-metrics"
  description = "Allow Lambda to publish CloudWatch metrics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = local.cloudwatch_namespace
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_metrics" {
  count      = var.enable_monitoring ? 1 : 0
  role       = module.lambda.lambda_role_name
  policy_arn = aws_iam_policy.cloudwatch_metrics[0].arn
}

# CloudWatch alarm for Lambda errors (catches any Lambda failures)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_monitoring && length(var.alarm_sns_topic_arns) > 0 ? 1 : 0
  alarm_name          = "${var.function_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Connectivity check Lambda is failing"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.lambda.lambda_function_name
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = module.lambda.lambda_function_tags
}

# CloudWatch alarms for critical endpoint failures
# Creates one alarm per critical target
# Only created when SNS topics are configured (for direct CloudWatch alerting)
# When using Datadog for monitoring, these can be skipped by leaving alarm_sns_topic_arns empty
resource "aws_cloudwatch_metric_alarm" "critical_endpoint_failure" {
  for_each = var.enable_monitoring && length(var.alarm_sns_topic_arns) > 0 ? {
    for target in var.monitoring_targets : "${target.host}:${target.port}" => target
    if try(target.critical, false)
  } : {}

  alarm_name          = "${var.function_name}-${replace(each.key, ":", "-")}-failure"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "EndpointConnectivity"
  namespace           = local.cloudwatch_namespace
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "CRITICAL: ${each.value.host}:${each.value.port} is unreachable"
  treat_missing_data  = "breaching"

  dimensions = {
    FunctionName = var.function_name
    Endpoint     = each.key
    Critical     = "true"
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = module.lambda.lambda_function_tags
}

# Aggregate alarm for any critical endpoint failure
# Only created when SNS topics are configured (for direct CloudWatch alerting)
resource "aws_cloudwatch_metric_alarm" "any_critical_failure" {
  count               = var.enable_monitoring && length(var.alarm_sns_topic_arns) > 0 && length([for t in var.monitoring_targets : t if try(t.critical, false)]) > 0 ? 1 : 0
  alarm_name          = "${var.function_name}-any-critical-failure"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "EndpointConnectivity"
  namespace           = local.cloudwatch_namespace
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "One or more critical endpoints are unreachable"
  treat_missing_data  = "breaching"

  dimensions = {
    FunctionName = var.function_name
    Critical     = "true"
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = module.lambda.lambda_function_tags
}
