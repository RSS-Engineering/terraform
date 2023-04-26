# security_hub

**security_hub** sets up Security Hub (as a member account) according to best-practice for security monitoring. Security Hub should be provisioned within each active region of an account. This should be provisioned together with the [guardduty](./guardduty.md) product.

This module is just one part of a recommended security monitoring architecture - see the [RSS-Engineering/platform-security-hub](https://github.com/RSS-Engineering/platform-security-hub) repo for more information.

## Example Usage

---

### Provision Security Hub in ap-northeast-1

```terraform
module "security_hub_ap-northeast-1" {
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/security_hub"
  providers = {
    aws = aws.ap-northeast-1
  }
}
```

It is also highly recommended to aggregate the security findings from Security Hub into a centralized account whose sole responsibility is Security Hub monitoring and notifications.

```terraform
resource "aws_securityhub_invite_accepter" "invitee" {
  depends_on = [module.security_hub_us-west-2.security_hub]
  master_id  = var.security_hub_admin_account_id
  providers = {
    aws = aws.us-west-2
  }
}
```

## Argument Reference

---

Currently no arguments are supported.

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
