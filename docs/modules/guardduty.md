# guardduty

**guardduty** sets up GuardDuty (as a member account) according to best-practice for security monitoring. GuardDuty should be provisioned within each active region of an account. This should be provisioned together with the [security_hub](./security_hub.md) product.

This module is just one part of a recommended security monitoring architecture - see the [RSS-Engineering/platform-security-hub](https://github.com/RSS-Engineering/platform-security-hub) repo for more information.

## Example Usage

---

### Provision GuardDuty in ap-northeast-1

```terraform
module "guardduty_ap-northeast-1" {
  source    = "git@github.com:RSS-Engineering/terraform//modules/guardduty?ref={commit}"
  instance  = var.environment
  providers = {
    aws = aws.sec-ap-northeast-1
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

- `guardduty_detector` - The [aws_guardduty_detector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector) that was provisioned. At minimum this exposes two attributes that may be useful:

  - `account_id` - The AWS account ID of the GuardDuty detector
  - `arn` - Amazon Resource Name (ARN) of the GuardDuty detector
  - `id` - The ID of the GuardDuty detector

  Example usage:

  ```terraform
  module.guardduty_ap-northeast-1.guardduty_detector.id
  ```
