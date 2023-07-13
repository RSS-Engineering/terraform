# Terraform Guidance

The purpose of this repo is to provide guidance on terraform patterns and also serve as a landing space for generic, sharable modules.

## [Setup and Topology](topology.md)

How a project is organized can have a large impact on maintainability as the project grows and updates are necessary.

[Click here for more details...](topology.md)

## [CI/CD Guidance](cicd/README.md)

Terraform manages your infrastructure by doing the best it can to adapt the current state of your infrastructure to the requested state as defined by your Terraform repo. To do this, Terraform creates a _plan_. How this plan is handled in a CI/CD setup is important to maintaining code review accountability and integrity between production deployment and your projects master branch.

[Click here for more details...](cicd/README.md)

## Reusable Modules

Terraform modules in this repository are designed to be generic and helpful to the majority case of apps.
They can be included in your Terraform code like this ([kms_secrets](modules/kms_secrets.md) for example):

```terraform
module "secrets" {
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/kms_secrets"

  context = {
    environment = "dev"
  }

  secrets = [{
    key        = "password"
    kms_key_id = "mrk-1234567890098765432"
    ciphertext = "aHVudGVyMg=="
  }]
}
```

Terraform good practice is to specify a commit hash when sourcing an external module to prevent module changes from unexpectly breaking your deployment pipeline.

---

### [api_gateway](modules/api_gateway.md)

The [api_gateway](modules/api_gateway.md) module exposes a simple interface for specifying an API Gateway with the AWS [API V1 resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) in a declarative manner.

### [datadog_aws_integration](modules/datadog_aws_integration.md)

The [datadog_aws_integration](modules/datadog_aws_integration.md) module creates the required IAM roles and polices for Datadog to integrate with your AWS account. It will also create the aws integration in datadog.

### [kms_secrets](modules/kms_secrets.md)

The [kms_secrets](modules/kms_secrets.md) module allows you to store multiple secrets in your repository in encrypted form. This provides secrets that terraform can use without needing them to be stored and managed in a separate secure store such as PasswordSafe, SecretsManager or as an SSM Param.

### [s3_bucket](modules/s3_bucket.md)

The [s3_bucket](modules/s3_bucket.md) module provision basic s3 buckets which are common across PE infrastructure. The main use case for this are for micro-uis and normal s3 storage, like for terraform state, configuration, logs, etc.

### [s3_access_logging](modules/s3_access_logging.md)

The [s3_access_logging](modules/s3_access_logging.md) module handles the logic for creating an s3 access log bucket along with enabling access logging on several buckets at once.

### [security_hub](modules/security_hub.md)/[guardduty](modules/guardduty.md)

The [security_hub](modules/security_hub.md) and [guardduty](modules/guardduty.md) modules provision best-practice security monitoring in an account, which can be used for notifications on potential security incidents. These should be provisioned together, and should be provisioned in all active regions in an account - not just the ones which have resources.
