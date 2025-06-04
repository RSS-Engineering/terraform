provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

variable "enable_xss_body_rule" {
  description = "Whether to enable the XSS body-only rule"
  type        = bool
  default     = false
}

locals {
  xss_body_rule = var.enable_xss_body_rule ? [{
    name                    = "${var.stage}_${var.region}_${var.service_name}_xss_body_rule"
    priority                = 30
    metric_name             = "${var.stage}_${var.region}_${var.service_name}_xss__body_rule"
    transformation_type     = "NONE"
    transformation_priority = 5
  }] : []
}

# Web ACL
resource "aws_wafv2_web_acl" "web_acl" {
  name  = "${var.stage}_${var.region}_${var.service_name}_web_acl"
  scope = "REGIONAL"
  count = var.enabled

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "${var.stage}_${var.region}_${var.service_name}_sql_injection_rule"
    priority = 10
    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          sqli_match_statement {
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 5
              type     = "URL_DECODE"
            }
          }
        }
        statement {
          sqli_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 5
              type     = "URL_DECODE"
            }
          }
        }
        statement {
          sqli_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 5
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.stage}_${var.region}_${var.service_name}_sql_injection_rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "${var.stage}_${var.region}_${var.service_name}_xss_rule"
    priority = 20
    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          xss_match_statement {
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 5
              type     = "URL_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 5
              type     = "URL_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 5
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.stage}_${var.region}_${var.service_name}_xss_rule"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = local.xss_body_rule
    content {
      name     = rule.value.name
      priority = rule.value.priority
      action {
        block {}
      }

      statement {
        or_statement {
          statement {
            xss_match_statement {
              field_to_match {
                body {}
              }
              text_transformation {
                priority = rule.value.transformation_priority
                type     = rule.value.transformation_type
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.metric_name
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.stage}_${var.region}_${var.service_name}_webacl"
    sampled_requests_enabled   = true
  }
}

# Web ACL Association
resource "aws_wafv2_web_acl_association" "web_acl_association" {
  resource_arn = var.acl_association_resource_arn
  web_acl_arn  = aws_wafv2_web_acl.web_acl[count.index].arn
  count        = var.enabled
}

resource "aws_cloudwatch_log_resource_policy" "web_acl_resource_policy" {
  count           = var.enabled
  policy_document = data.aws_iam_policy_document.web_acl_policy_document[count.index].json
  policy_name     = "${var.stage}_${var.region}_${var.service_name}_webacl_resource_policy"
}

data "aws_iam_policy_document" "web_acl_policy_document" {
  count   = var.enabled
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type        = "Service"
    }
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.web_acl_log[count.index].arn}:*"]
    condition {
      test     = "ArnLike"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
      variable = "aws:SourceArn"
    }
    condition {
      test     = "StringEquals"
      values   = [tostring(data.aws_caller_identity.current.account_id)]
      variable = "aws:SourceAccount"
    }
  }
}

# CloudWatch Log Group for WAFv2 Logging
resource "aws_cloudwatch_log_group" "web_acl_log" {
  name  = "aws-waf-logs-${var.stage}_${var.region}_${var.service_name}"
  count = var.enabled
}

# Log web ACL traffic logs.
resource "aws_wafv2_web_acl_logging_configuration" "web_acl_logging_config" {
  count                   = var.enabled
  log_destination_configs = [aws_cloudwatch_log_group.web_acl_log[count.index].arn]
  resource_arn            = aws_wafv2_web_acl.web_acl[count.index].arn

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  redacted_fields {
    single_header {
      name = "x-auth-token"
    }
  }
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
