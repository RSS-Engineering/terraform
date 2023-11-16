# api_gateway

**api_gateway** exposes a simple interface for specifying an API Gateway with the AWS [API V1 resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api). The module signature is patterned to be more declarative and similar to the [API Gateway V2 resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api)

Amazon exposes API gateways with 2 different APIs but they support different features. [Read More Here](https://www.tinystacks.com/blog-post/api-gateway-rest-vs-http-api-what-are-the-differences/) to see which version is right for your project.

This module abstracts the V1 API since the V2 API is sufficiently well-designed that (for now) does not require an abstraction.


## Example Usage

---

```terraform
module "api_gateway" {
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/api_gateway"

  name                  = "API Gateway"
  description           = "REST Endpoints"
  stage_name            = "v1"
  tags                  = {}
  log_retention_in_days = 0

  authorizers = {
    "authorizer_lambda" = {
      "function_arn"        = module.lambda_authorizer.lambda_function_arn
      "function_invoke_arn" = module.lambda_authorizer.lambda_function_invoke_arn
    }
  }

  # Specify lambdas by (arbitrary) key and function-name for later reference via a route.
  # The function ARN and invocation ARNs also have to be specified.
  lambdas = {
    "rest_api_handler" = {
      "function_arn"        = module.lambda_rest_api.lambda_function_arn
      "function_invoke_arn" = module.lambda_rest_api.lambda_function_invoke_arn
    }
  }

  routes = {
    # Send requests to / to the "rest_api_handler" lambda after passing through the authorizer.
    # The root route must always be specified.
    "/" = {
      authorizer_key = "authorizer_lambda"
      lambda_key     = "rest_api_handler"
    }

    # Send GET requests to /categories to the proxy_url (bypassing the authorizer)
    "/categories" = {
      method = "GET"
      type = "HTTP_PROXY"
      proxy_url = "https://api.notifications.rackspace.com/categories"
    }

    # Send GET requests to /categories/{any_subpath+} to the proxy_url (bypassing the authorizer)
    "/categories/{any_subpath}" = {
      method = "GET"
      type = "HTTP_PROXY"
      proxy_url = "https://api.notifications.rackspace.com/categories/{any_subpath}}"
    }

    # Send GET requests to /health to the "rest_api_handler" lambda (bypassing the authorizer)
    "/health" = {
      method     = "GET"
      lambda_key = "rest_api_handler"
    }

    # Send all unmatched requests to the "rest_api_handler" lambda (after passing through the authorizer)
    "/{proxy+}" = {
      method         = "ANY"
      authorizer_key = "authorizer_lambda"
      lambda_key     = "rest_api_handler"
    }
  }

}

```

## Argument Reference

---

The following arguments are supported:

* `name` - The API Gateway name. Also added as a partial name to a log role and execution permission.
* `description` - The API Gateway description.
* `stage_name` - API stage name, applied as suffix to log group name and passed as the `STAGE_NAME` variable. (Use this for frameworks that need to know the _base_path_.)
* `endpoint_type` - (optional, default "EDGE") - Endpoint configuration type. ["REGIONAL"](https://docs.aws.amazon.com/apigateway/latest/developerguide/create-regional-api.html) or ["EDGE"](https://docs.aws.amazon.com/apigateway/latest/developerguide/create-api-resources-methods.html)
* `routes` - A mapping of path prefixes to `route` mappings to define the behavior at that path prefix (The leading '/' is cosmetic. Paths can contain up to five levels deep.).
* `tags` - (optional) A mapping of tags to be applied to all resources.
* `log_retention_in_days` - (optional, default 0) - number of days to retain logs. 0 (the default) means to never expire logs. Other valid values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653.
* `authorizers` - A mapping of string keys to an attribute mapping. The keys are arbitrary for reference in `route` entries.
* `lambdas` - A mapping of string keys to an attribute mapping. The keys are arbitrary for reference in `route` entries.
* `set_cloudwatch_role` - A boolean indicating if the API Gateway Cloudwatch role should be set
* `apigateway_cloudwatch_role_arn` - (optional) If `set_cloudwatch_role` is true, then specifying this will set the specific role. If not provided, a role will be created.
* `redeployment_hash` - (optional) - Entropy variable to trigger a deployment to be made. If omitted, this module will do its best to detect applicable changes.

The `authorizers` attribute map contains:

* `function_arn` - the ARN of the Lambda function (omit for external account authorizers)
* `function_invoke_arn` - the special invocation ARN of the Lambda function
* `authorizer_result_ttl_in_seconds` - (optional, default to "900") ttl in seconds for an authorizer result.
* `authorizer_type` - (optional, default "TOKEN") type of authorizer determining the payload, other possible values: "REQUEST" and "COGNITO_USER_POOLS".

The `lambda` attribute map contains:

* `function_arn` - the ARN of the Lambda function
* `function_invoke_arn` - the special invocation ARN of the Lambda function

A `route` mapping can contain:

* `method` - API-Gateway [http method](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method#http_method) default: ANY
* `type` - API Gateway [integration type](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#type). Only "AWS_PROXY" and "HTTP_PROXY" supported currently. Default: "AWS_PROXY"
* `proxy_url` - if type is "HTTP_PROXY", proxy requests to this endpoint (otherwise this argument is ignored)
* `lambda_key` - if type is "AWS_PROXY", send requests to the lambda assigned to this arbitrary key in the `lambdas` argument (otherwise argument is ignored).
* `authorizer_key` - (optional) if type is "AWS_PROXY", add this authorizer to the route (otherwise argument is ignored).
* `authorizer_arn` - (optional) if type is "AWS_PROXY", add this authorizer from another AWS account to the route (otherwise argument is ignored).
* `headers` - (optional) an optional string-mapping of header names to static values. (example: "Host=example.com;Accept=application/json")


## Attributes Reference

---

In addition to all arguments above, the following attributes are exported:

* `api_id` - The id of the API Gateway
* `hostname` - The string hostname of the API Gateway
* `stage_url` - The full url of the exposed stage
* `stage_arn` - The ARN of the exposed stage
* `log_role_arn` - The cloudwatch log role created if `apigateway_cloudwatch_role_arn` is not supplied
* `execution_arn` - The execution_arn of the API gateway, usually used as part of the `source_arn` for lambda permissions
