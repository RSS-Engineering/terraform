terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = var.function_name
  description   = "Tests TCP and HTTPS connectivity"
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  
  layers = var.enable_monitoring ? [
    "arn:aws:lambda:${data.aws_region.current.name}:901920570463:layer:aws-otel-nodejs-amd64-ver-1-7-0:2"
  ] : []
  
  environment_variables = merge(
    {
      NODE_OPTIONS = "--experimental-strip-types --experimental-transform-types"
    },
    var.enable_monitoring ? {
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/otel-handler"
      DATADOG_API_KEY         = var.datadog_api_key
      JANUS_ENVIRONMENT       = var.janus_environment
    } : {}
  )

  source_path = [
    {
      path             = "${path.module}/lambda"
      npm_requirements = true
    }
  ]

  timeout     = var.timeout
  memory_size = var.memory_size

  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids
  attach_network_policy  = true

  cloudwatch_logs_retention_in_days = var.log_retention_days

  tags = {
    connectivity_check         = "true"
    connectivity_check_version = "v1"
  }
}

data "aws_region" "current" {}
