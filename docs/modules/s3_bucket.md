# s3_bucket

**s3_bucket** Creates a s3 bucket with recommended security defaults for a private bucket.

This automatically enables several security settings like public access block settings, bucket policies, and has prebaked policies for [CloudFront Origin Access Control](https://aws.amazon.com/blogs/networking-and-content-delivery/amazon-cloudfront-introduces-origin-access-control-oac/). This avoids the requirement of s3 website configuration or public access to a bucket when serving assets.

If your bucket already exists and uses ACLs (which are deprecated), you may need to set a private ACL on the bucket first before migrating to using this module. This module uses [Bucket Ownership Controls](https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html) and bucket policies instead of ACLs to control bucket permissions.

## Example Usage

---

### Terraform State Bucket

```terraform
module "terraform_state_bucket" {
  source = "git@github.com:RSS-Engineering/terraform//modules/s3_bucket?ref=<commit>"

  name                       = "whatever-terraform-state-${var.environment}-${local.account_id}"
  enable_versioning          = true
  noncurrent_expiration_days = 90
}
```

### Micro-UI

```terraform
module "micro_ui" {
  source = "git@github.com:RSS-Engineering/terraform//modules/s3_bucket?ref=<commit>"

  name              = "whatever-ui-${var.environment}-${local.account_id}"
  cloudfront_arns   = ["arn:aws:cloudfront::507897595701:distribution/E285AA1RBBB6EJ"]
}
```

### Specifying bucket policies

```terraform
module "test_bucket" {
  source = "git@github.com:RSS-Engineering/terraform//modules/s3_bucket?ref=<commit>"

  name              = "testbucket"
  bucket_policies   = [
    data.aws_iam_policy_document.example_policy1.json,
    data.aws_iam_policy_document.example_policy2.json
  ]
}

data "aws_iam_policy_document" "example_policy1" {
  # snip...
}

data "aws_iam_policy_document" "example_policy2" {
  # snip...
}
```

## Argument Reference

---

The following arguments are supported:

- `name` - name of the bucket
- `bucket_policies` - list of additional bucket policies (as a json string) to attach to the bucket
- `enable_versioning` - whether or not to enable versioning, defaults to `false`
- `expiration_days` - number of days until objects expire, defaults to `null` for no expiration
- `noncurrent_expiration_days` - number of days until noncurrent versions of objects expire, defaults to `null` for no expiration
- `additional_expiration_rules` - list of additional expiration rules, see `additional_expiration_rules` below
- `cloudfront_arns` - list of cloudfront distributions to allow read access to the bucket

### additional_expiration_rules

Must specify either `expiration_days` or `noncurrent_expiration_days`

- `prefix` - s3 object prefix that the rule applies to
- `expiration_days` - number of days until objects expire, defaults to `null` for no expiration
- `noncurrent_expiration_days` - number of days until noncurrent versions of objects expire, defaults to `null` for no expiration

## Attributes Reference

---

In addition to all arguments above, the following attributes are exported:

- `id` - The S3 bucket name
- `arn` - ARN of the S3 bucket
