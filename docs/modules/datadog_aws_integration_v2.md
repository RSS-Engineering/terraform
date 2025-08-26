# datadog_aws_integration_v2

**datadog_aws_integration_v2** Creates the required IAM roles and polices for Datadog to integrate with your AWS account. It will also create the aws integration in datadog.

## Example Usage

```terraform
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    datadog = {
      source  = "DataDog/datadog"
    }
  }
}

provider "datadog" {
  app_key = "" # Recommended to use the kms_secrets module here
  api_key = "" # Recommended to use the kms_secrets module here
}

module "datadog_aws_integration_v2" {
  source = "git@github.com:RSS-Engineering/terraform//modules/datadog_aws_integration_v2?ref={commit}"

  tags = [
    "account:${data.aws_caller_identity.current.account_id}",
    "region:${data.aws_region.current.name}",
    "service:Application",
    "env:production"
  ]
  included_metrics = ["AWS/SQS", "AWS/ElasticMapReduce"]
}
```

## Argument Reference

---

The following arguments are supported:

* `tags` - (optional) A list of tags to to apply to all metrics in the account.
* `included_metrics` - (optional) List of metric namespaces to be collected. A list of namespaces can be found at the [available namespace rules API endpoint](https://docs.datadoghq.com/api/v1/aws-integration/#list-namespace-rules). Nothing will be collected if this is not set.
