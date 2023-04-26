# guardduty

**guardduty** sets up GuardDuty (as a member account) according to best-practice for security monitoring. GuardDuty should be provisioned within each active region of an account. This should be provisioned together with the [security_hub](./security_hub.md) product.

This module is just one part of a recommended security monitoring architecture - see the [RSS-Engineering/platform-security-hub](https://github.com/RSS-Engineering/platform-security-hub) repo for more information.

## Example Usage

---

### Provision GuardDuty in ap-northeast-1

```terraform
module "guardduty_ap-northeast-1" {
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/guardduty"
  providers = {
    aws = aws.sec-ap-northeast-1
  }
}
```

It is also highly recommended to aggregate the security findings from GuardDuty into a centralized account whose sole responsibility is GuardDuty monitoring and notifications.

```terraform
resource "aws_guardduty_invite_accepter" "invitee" {
  depends_on        = [module.guardduty_us-west-2.guardduty_detector]
  detector_id       = var.guardduty_detector_id
  master_account_id = var.security_hub_admin_account_id
  providers = {
    aws = aws.sec-us-west-2
  }
}
```

## Argument Reference

---

Currently no arguments are supported.

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
