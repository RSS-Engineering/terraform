# security_hub

**security_hub** sets up Security Hub (as a member account) according to best-practice for security monitoring. Security Hub should be provisioned within each active region of an account. This should be provisioned together with the [guardduty](./guardduty.md) product.

This module is just one part of a recommended security monitoring architecture - see the [RSS-Engineering/platform-security-hub](https://github.com/RSS-Engineering/platform-security-hub) repo for more information.

## Example Usage

---

### Provision Security Hub in ap-northeast-1

```terraform
module "security_hub_ap-northeast-1" {
  source    = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/security_hub"
  instance  = var.environment
  providers = {
    aws = aws.ap-northeast-1
  }
}
```

## Argument Reference

---

The following arguments are supported:

- `instance` - The instance of GuardDuty to accept invitations from. By default, this accepts `dev`, `prod`, and defaults to `null`. When `null`, this module will not be configured to accept invitations.
- `admin_account` - Map of AWS Account IDs to accept invitations from, defaults to the `dev` and `prod` instances of Security Hub provisioned in the RSS-Engineering/platform-security-hub repo.

## Attributes Reference

---

In addition to all arguments above, the following attributes are exported:

- `security_hub` - The [aws_securityhub_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_account) that was provisioned. At minimum this exposes two attributes that may be useful:

  - `id` - AWS Account ID.
  - `arn` - ARN of the SecurityHub Hub created in the account.

  Example usage:

  ```terraform
  module.security_hub_ap-northeast-1.security_hub.arn
  ```
