# s3_access_logging

**s3_access_logging** sets up [s3 access logging](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html) for a set of buckets. This handles creation of the log destination bucket, enabling bucket logging on the specified source buckets, and handles all the required bucket policy/permissions to get this to work.

## Example Usage

---

### Enable Access Logging

```terraform
module "s3_access_log_bucket" {
  source = "git@github.com:RSS-Engineering/terraform//modules/s3_access_logging?ref=<commit>"

  bucket_name = "whatever-logs-${var.environment}-${local.account_id}"
  log_sources = [
    {
      bucket_name = module.state_bucket_example.id
    },
    {
      bucket_name = module.lambda_bucket_example.id
    }
  ]
}
```

## Argument Reference

---

The following arguments are supported:

- `log_sources` - list of bucket names to enable logging for
- `default_expiration_days` - number of days to keep logs for, defaults to `400`
- `bucket_name` - name of the logging destination bucket to be created

## Attributes Reference

---

In addition to all arguments above, the following attributes are exported:

- `id` - The S3 bucket name
- `arn` - ARN of the S3 bucket
