# datadog_aws_integration

**datadog_aws_integration** Creates the required IAM roles and polices for Datadog to integrate with your AWS account. It will also create the aws integration in datadog.

## Example Usage

---

### Password secret available at build-time

```terraform
module "datadog_aws_integration" {
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/datadog_aws_integration"

  app_key = "app_key_from_datadog_console"
  api_key = module.secrets.plaintext["datadog_api_key"] # Recommended to use the kms_secrets module here
  
  host_tags = {
    "account" : data.aws_caller_identity.current.account_id,
    "region" : data.aws_region.current.name,
    "service" : "Application",
    "env" : "production",
  }
}
```

## Argument Reference

---

The following arguments are supported:

* `app_key` - Datadog integration App key
* `api_key` - (sensitive) Datadog integration API key
* `host_tags` - A map of strings to be applied as tags to each metric ingested through this integration. The key-value pair will be converted to a single tag formatted like "{k}:{v}"
