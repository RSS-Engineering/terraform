locals {
  authorizer_list = [
    for key, value in var.routes :
    value["authorizer_key"] if lookup(value, "authorizer_key", "") != ""
  ]
  integration_lambda_list = [
    for key, value in var.routes :
    value["lambda_key"] if lookup(value, "lambda_key", "") != ""
  ]
  authorizer_keys = {
    for k in distinct(local.authorizer_list) :
    k => ""
  }
  integration_keys = {
    for k in distinct(local.integration_lambda_list) :
    k => ""
  }
  routes = {
    for key, value in var.routes : trimprefix(key, "/") => {
      method         = lookup(value, "method", "ANY")
      authorizer_key = lookup(value, "authorizer_key", "")
      lambda_key     = lookup(value, "lambda_key", "")
      proxy_url      = lookup(value, "proxy_url", "")
      type           = lookup(value, "type", "AWS_PROXY")
    }
  }
  subroutes = {for key, value in local.routes : key => value if key != ""}
}

data "aws_region" "current" {}

# API GATEWAY AUTHORIZER LAMBDA
data "aws_lambda_function" "lambda" {
  for_each = var.lambdas

  function_name = each.value["function_name"]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "apigateway.amazonaws.com",
        "cloudwatch.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "invocation_role" {
  name = "api_gateway_auth_invocation_role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "invocation_policy" {
  name = "apigateway_authorization_invocation_policy"
  role = aws_iam_role.invocation_role.id

  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Action" = "lambda:InvokeFunction",
        "Effect" = "Allow",
        "Resource" = [
          for key in distinct(local.authorizer_list) : data.aws_lambda_function.lambda[key].arn
        ]
      }
    ]
  })
}

resource "aws_api_gateway_authorizer" "authorizer" {
  for_each = local.authorizer_keys

  name        = "api_authorizer_${each.key}"
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  # authorizer_uri looks funny because of https://github.com/hashicorp/terraform-provider-aws/issues/26619
  authorizer_uri                   = replace(data.aws_lambda_function.lambda[each.key].invoke_arn, "/\\:\\d{1,3}\\/invocations/", "/invocations")
  authorizer_credentials           = aws_iam_role.invocation_role.arn
  identity_source                  = lookup(var.lambdas[each.key], "identity_source", "method.request.header.X-Auth-Token")
  authorizer_result_ttl_in_seconds = parseint(lookup(var.lambdas[each.key], "authorizer_result_ttl_in_seconds", "900"), 10)
}
# END

# API_GATEWAY
resource "aws_lambda_permission" "web_rest_invoke_permission" {
  for_each = local.integration_keys

  statement_id  = "allow-${var.name}-restapi-invoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda[each.key].function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_rest_api" "rest_api" {
  name        = var.name
  description = var.description

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  tags = var.tags
}

# routes
resource "aws_api_gateway_resource" "rest_api_route_resource" {
  for_each = local.subroutes

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_method" "rest_api_route_method" {
  for_each = local.routes

  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = each.key != "" ? aws_api_gateway_resource.rest_api_route_resource[each.key].id : aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method   = each.value["method"]
  authorization = each.value["authorizer_key"] == "" ? "NONE" : "CUSTOM"
  authorizer_id = (
    each.value["authorizer_key"] == ""
    ? null
    : aws_api_gateway_authorizer.authorizer[each.value["authorizer_key"]].id
  )
}

resource "aws_api_gateway_integration" "rest_api_route_integration" {
  for_each = local.routes

  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = each.key != "" ? aws_api_gateway_resource.rest_api_route_resource[each.key].id : aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method             = aws_api_gateway_method.rest_api_route_method[each.key].http_method
  integration_http_method = each.value["lambda_key"] != "" ? "POST" : each.value["method"]
  type                    = each.value["type"]
  uri = (
    each.value["lambda_key"] != ""
    ? replace(data.aws_lambda_function.lambda[each.value["lambda_key"]].invoke_arn, "/\\:\\d{1,3}\\/invocations/", "/invocations")
    : each.value["proxy_url"]
  )
  cache_key_parameters = []
  request_parameters   = {}
  request_templates    = {}
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.rest_api_route_integration[""], # The root route
  ]
  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  triggers = {
    redeployment = sha1(jsonencode(concat(
      [
        for key, value in aws_api_gateway_resource.rest_api_route_resource : value.id
        ], [
        for key, value in aws_api_gateway_method.rest_api_route_method : value.id
        ], [
        for key, value in aws_api_gateway_integration.rest_api_route_integration : value.id
        ], [
        for key, value in aws_api_gateway_authorizer.authorizer : value.id
      ]
    )))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "api-gateway-logs" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.rest_api.id}/${var.stage_name}"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = var.stage_name

  variables = {
    STAGE_NAME = var.stage_name
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api-gateway-logs.arn
    format = jsonencode(
      {
        domainName   = "$context.domainName"
        method       = "$context.httpMethod"
        path         = "$context.path"
        ip           = "$context.identity.sourceIp"
        requestId    = "$context.requestId"
        requestTime  = "$context.requestTime"
        status       = "$context.status"
        errorMessage = "$context.error.message"
        xRayTraceId  = "$context.xrayTraceId"
      }
    )
  }

  xray_tracing_enabled = true
  tags                 = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_iam_role" "log_role" {
  name               = "${var.name}-apigateway-log-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

# Attach AmazonAPIGatewayPushToCloudWatchLogs policy to API Gateway role to allow it to write logs
resource "aws_iam_role_policy_attachment" "attach_cloudwatch_logging" {
  role       = aws_iam_role.log_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.log_role.arn
}
