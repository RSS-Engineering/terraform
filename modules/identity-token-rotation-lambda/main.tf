data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "token" {
  name                    = "${var.resource_path}/service-account/token"
  description             = "Service account racker token"
  recovery_window_in_days = 0
}

module "lambda_layer" {
  source                   = "terraform-aws-modules/lambda/aws"
  version                  = "~> 2.0"
  create_layer             = true
  layer_name               = "${var.resource_prefix}-token-rotation"
  compatible_architectures = ["x86_64"]
  compatible_runtimes      = [var.lambda_runtime]
  runtime                  = var.lambda_runtime
  recreate_missing_package = false
  source_path = [
    {
      path             = path.module,
      pip_requirements = "${path.module}/requirements.txt"
      # Exclude files that aren't really dependencies
      patterns = [
        "!python/src/.*",
        "!python/requirements\\.txt"
      ],
      # This is needed, because the contents of the layer are extracted to /opt
      # and the Python runtime is looking for packages in /opt/python
      prefix_in_zip = "python"
    }
  ]
}

module "lambda_function" {
  source         = "terraform-aws-modules/lambda/aws"
  version        = "~> 2.0"
  function_name  = "${var.resource_prefix}-token-rotation"
  handler        = "rotation.handler"
  memory_size    = 128
  timeout        = 60
  runtime        = var.lambda_runtime
  tracing_mode   = "Active"
  source_path    = "${path.module}/src"
  vpc_subnet_ids         = var.private_subnet_ids
  vpc_security_group_ids = var.security_group_ids
  layers = [
    module.lambda_layer.lambda_layer_arn
  ]
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
  function_name = module.lambda_function.lambda_function_arn
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.token.arn
}

resource "aws_secretsmanager_secret_rotation" "this" {
  secret_id           = aws_secretsmanager_secret.token.id
  rotation_lambda_arn = module.lambda_function.lambda_function_arn
  rotation_rules {
    schedule_expression = var.rotation_schedule_expression
  }
}
