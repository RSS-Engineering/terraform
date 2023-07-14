resource "aws_s3_bucket" "this" {
  bucket = var.name
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json
}

data "aws_iam_policy_document" "this" {
  source_policy_documents = var.bucket_policies

  statement {
    sid    = "RequireHttps"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = var.cloudfront_arns

    content {
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }

      actions = [
        "s3:GetObject"
      ]

      resources = [
        "${aws_s3_bucket.this.arn}/*"
      ]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceArn"
        values   = [statement.value]
      }
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = { for expire_rule in var.additional_expiration_rules : expire_rule.prefix => expire_rule }

    content {
      id     = "expire-${substr(rule.value.prefix, 0, 248)}" # max is 255 chars
      status = "Enabled"

      dynamic "expiration" {
        for_each = { for val in [rule.value.expiration_days] : val => val if val != null }

        content {
          days = rule.value.expiration_days
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = { for val in [rule.value.noncurrent_expiration_days] : val => val if val != null }

        content {
          noncurrent_days = rule.value.noncurrent_expiration_days
        }
      }

      filter {
        prefix = rule.value.prefix
      }
    }
  }

  rule {
    id     = "expire-default"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    dynamic "expiration" {
      for_each = { for val in [var.expiration_days] : val => val if val != null }

      content {
        days = var.expiration_days
      }
    }

    dynamic "noncurrent_version_expiration" {
      for_each = { for val in [var.noncurrent_expiration_days] : val => val if val != null }

      content {
        noncurrent_days = var.noncurrent_expiration_days
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
