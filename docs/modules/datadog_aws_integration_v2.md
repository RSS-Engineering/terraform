# datadog_aws_integration_v2

**datadog_aws_integration_v2** Creates the required IAM roles and polices for Datadog to integrate with your AWS account. It will also create the aws integration in datadog.

## Example Usage

```terraform
module "datadog_aws_integration_v2" {
  source = "git@github.com:RSS-Engineering/terraform//modules/datadog_aws_integration_v2?ref={commit}"

  app_key = "" # Recommended to use the kms_secrets module here
  api_key = "" # Recommended to use the kms_secrets module here

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

- `app_key` - (required) The Datadog application key.
- `api_key` - (required) The Datadog API key.
- `tags` - (optional) A list of tags to to apply to all metrics in the account.
- `excluded_metrics` - (optional) List of metric namespaces to be excluded. Use
[datadog_integration_aws_available_namespaces](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/data-sources/integration_aws_available_namespaces)
data source to get allowed values or you can find them at [AWS services metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/aws-services-cloudwatch-metrics.html).
Defaults to ["AWS/SQS", "AWS/ElasticMapReduce"]. AWS/SQS and AWS/ElasticMapReduce are excluded by default to reduce your AWS CloudWatch costs from GetMetricData API calls.
