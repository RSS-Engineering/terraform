data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "token" {
  name                    = "${var.resource_path}/service-account/token"
  description             = "Service account racker token"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "token" {
  secret_id     = aws_secretsmanager_secret.token.id
  secret_string = "none"
  # Changes to the password in Terraform should not trigger a change in state to Secrets Manager
  lifecycle {
    ignore_changes = [
      secret_string
    ]
  }
}

data archive_file "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
}

module "token_rotation_lambda" {
  source         = "terraform-aws-modules/lambda/aws"
  version        = "~> 5.0.0"
  function_name  = "${var.resource_prefix}-token-rotation"
  handler        = "src.rotation.handler"
  memory_size    = 128
  timeout        = 60
  runtime        = var.lambda_runtime
  create_package = true
  tracing_mode   = "Active"
  source         = data.archive_file.lambda.output_path

  vpc_subnet_ids         = var.private_subnet_ids
  vpc_security_group_ids = var.security_group_ids
  environment_variables  = {
    POWERTOOLS_SERVICE_NAME    = "${var.resource_prefix}-token-rotation"
    SERVICE_ACCOUNT_SECRET_ARN = var.service_account_secret_arn
    USE_JANUS_PROXY            = var.use_janus_proxy

  }
  attach_tracing_policy    = true
  attach_network_policy    = true
  attach_policy_statements = true
  policy_statements        = {
    secrets_manager_write = {
      effect  = "Allow",
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage"
      ],
      resources = [aws_secretsmanager_secret.token.arn]
    }
    secrets_manager_read = {
      effect  = "Allow",
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
      ],
      resources = [var.service_account_secret_arn]
    }
  }
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = module.token_rotation_lambda.lambda_function_arn
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.token.arn
}

resource "aws_secretsmanager_secret_rotation" "this" {
  secret_id           = aws_secretsmanager_secret.token.id
  rotation_lambda_arn = module.token_rotation_lambda.lambda_function_arn
  rotation_rules {
    schedule_expression = "rate(6 hours)"
  }
}
