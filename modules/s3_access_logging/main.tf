data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

module "s3_access_log_bucket" {
  source = "../s3_bucket"

  name              = var.bucket_name
  enable_versioning = false
  bucket_policies   = [data.aws_iam_policy_document.server_access_logs_policy.json]
  expiration_days   = var.default_expiration_days

  additional_expiration_rules = [
    for source in var.log_sources : {
      expiration_days = source.expiration_days
      prefix          = "${source.bucket_name}/"
    } if source.expiration_days != var.default_expiration_days
  ]
}

# https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html
data "aws_iam_policy_document" "server_access_logs_policy" {
  dynamic "statement" {
    for_each = { for source in var.log_sources : source.bucket_name => source }

    content {
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["logging.s3.amazonaws.com"]
      }

      actions = [
        "s3:PutObject"
      ]

      resources = [
        "${module.s3_access_log_bucket.arn}/${statement.key}*"
      ]

      condition {
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = ["arn:aws:s3:::${statement.key}"]
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [local.account_id]
      }
    }
  }
}

resource "aws_s3_bucket_logging" "bucket_logging" {
  for_each = { for source in var.log_sources : source.bucket_name => source }

  bucket = each.key

  target_bucket = module.s3_access_log_bucket.id
  target_prefix = "${each.key}/"
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.s3_access_log_bucket
  to   = module.s3_access_log_bucket.aws_s3_bucket_lifecycle_configuration.this
}
