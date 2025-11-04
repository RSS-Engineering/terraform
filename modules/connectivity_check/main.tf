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
  description   = "Tests TCP and HTTPS connectivity from subnets: ${join(", ", var.subnet_ids)}"
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  environment_variables = {
    NODE_OPTIONS = "--experimental-transform-types"
  }

  source_path = [
    {
      path             = "${path.module}/lambda"
      # lambda has no npm dependencies, so this can be skipped
      npm_requirements = false
    }
  ]

  timeout     = var.timeout
  memory_size = var.memory_size

  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids
  attach_network_policy  = true

  cloudwatch_logs_retention_in_days = var.log_retention_days
}
