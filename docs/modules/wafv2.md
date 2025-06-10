# wafv2

**wafv2** is a web application firewall that lets you monitor the HTTP and HTTPS requests that are forwarded to a protected resource like Amazon CloudFront distribution, Amazon API Gateway REST API, Application Load Balancer, etc.

## Example Usage

```terraform
module "wafv2" {
  source                       = "github.com/RSS-Engineering/terraform//modules/wafv2?ref=<commit-id>"

  # Required variables
  stage                        = var.stage
  region                       = var.region
  service_name                 = var.service_name
  scope                        = "REGIONAL" # Use "CLOUDFRONT" for AWS CloudFront distribution
  enable_xss_body_rule         = false # Use false to skip xss body rule or true to create a body rule
  acl_association_resource_arn = "arn:aws:apigateway:${var.region}::/restapis/${module.device_service_api.api_id}/stages/${var.stage}"
  enabled                      = 1
}
```

## Argument Reference

---

The following arguments are supported:

* `enabled` - Enable or disable the WAF deployment. It is Set to 0 by default to ensure unintentional deployment doesn't occur.
* `scope` - Specifies whether WAF deployment for an AWS CloudFront distribution or for a regional application. Valid values are **CLOUDFRONT** or **REGIONAL**. To work with CloudFront, you must specify the region **us-east-1 (N. Virginia)** on the AWS provider.