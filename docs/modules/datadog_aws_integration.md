# datadog_aws_integration

**datadog_aws_integration** Creates the required IAM roles and polices for Datadog to integrate with your AWS account. It will also create the aws integration in datadog.

## Example Usage

```terraform
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "3.18.0"
    }
  }
}

locals {
  enable_datadog = true
  api_key = "" # Recommended to use the kms_secrets module here
  app_key = "" # Recommended to use the kms_secrets module here
}

provider "datadog" {
  app_key = local.app_key
  api_key = local.api_key

  validate = local.enable_datadog
  pagerduty_integration = "@pagerduty-${var.app_name}-${var.environment}"
}

module "datadog_aws_integration" {
  count = local.enable_datadog ? 1 : 0
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/datadog_aws_integration"

  host_tags = {
    "account" : data.aws_caller_identity.current.account_id,
    "region" : data.aws_region.current.name,
    "service" : "Application",
    "env" : "production",
  }
  namespace_rules = {
    "api_gateway" : true,
    "cloudfront" : true,
    "cloudwatch_events" : true
  }
}

resource "datadog_monitor" "apigateway_latency_monitor" {
  count = local.enable_datadog ? 1 : 0

  name               = "[${upper(var.environment)}] ${title(var.app_name)} - APIGateway HTTP Latency"
  type               = "query alert"
  escalation_message = local.pagerduty_integration
  query              = "max(last_10m):sum:aws.apigateway.latency{service:${var.app_name},env:${var.environment}} > 3000"
  notify_no_data     = false
  notify_audit       = false
  evaluation_delay = 900
  monitor_thresholds {
    critical = 3000
    critical_recovery = 1800
  }
  tags               = [
    for k, v in local.dd_tags : "${k}:${v}"
  ]

  message = <<EOF
${title(var.app_name)} ${title(var.environment)} is experiencing high latency. Investigate! ${local.pagerduty_integration}
EOF
}
```

## Argument Reference

---

The following arguments are supported:

* `host_tags` - (optional) A map of strings to be applied as tags to each metric ingested through this integration. The key-value pair will be converted to a single tag formatted like "{k}:{v}"
* `namespace_rules` - (optional) Specifically enables or disables metric collection for specific AWS namespaces for this _AWS account only_. A list of namespaces can be found at the [available namespace rules API endpoint](https://docs.datadoghq.com/api/v1/aws-integration/#list-namespace-rules). Omitting a namespace will not change it from the default integration settings.
