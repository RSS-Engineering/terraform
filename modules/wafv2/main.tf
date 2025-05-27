provider "aws" {
  region = var.region
}

# CloudWatch Log Group for WAFv2 Logging
resource "aws_cloudwatch_log_group" "waf_log_group" {
  name              = "/aws/wafv2/${var.stage}_${var.region}_${var.api_name}_waf_logs"
  count             = var.enabled
}

# WAFv2 Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_log_group[count.index].arn]
  resource_arn            = aws_wafv2_web_acl.web_acl[count.index].arn
  count                  = var.enabled
}

# IP Set for Throttling
resource "aws_wafv2_ip_set" "iplist_throttle" {
  name               = "${var.stage}_${var.region}_${var.api_name}_iplist_throttle"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = [var.iplist_throttle_CIDR_0]
  count              = var.enabled
}

# IP Set for Blacklist
resource "aws_wafv2_ip_set" "iplist_blacklist" {
  name               = "${var.stage}_${var.region}_${var.api_name}_iplist_blacklist"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = []
  count              = var.enabled
}

# XSS Match Conditions
resource "aws_wafv2_rule_group" "xss_match_conditions" {
  name     = "${var.stage}_${var.region}_${var.api_name}_xss_match_conditions"
  scope    = "REGIONAL"
  capacity = 50
  count    = var.enabled

  rule {
    name     = "xss_rule"
    priority = 1

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
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              single_header {
                name = "cookie"
              }
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}xssmatch"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}xssmatchgroup"
    sampled_requests_enabled   = true
  }
}

# SQL Injection Match Conditions
resource "aws_wafv2_rule_group" "sql_injection_match_set" {
  name     = "${var.stage}_${var.region}_${var.api_name}_sql_injection_match_set"
  scope    = "REGIONAL"
  capacity = 50
  count    = var.enabled

  rule {
    name     = "sql_injection_rule"
    priority = 1

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
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          sqli_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          sqli_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          sqli_match_statement {
            field_to_match {
              single_header {
                name = "cookie"
              }
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}sqlinjection"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}sqlinjectiongroup"
    sampled_requests_enabled   = true
  }
}

# Path Traversal, LFI, RFI
resource "aws_wafv2_rule_group" "byte_set_traversal" {
  name     = "${var.stage}_${var.region}_${var.api_name}_byte_match_set"
  scope    = "REGIONAL"
  capacity = 50
  count    = var.enabled

  rule {
    name     = "traversal_rule"
    priority = 1

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          byte_match_statement {
            search_string         = "../"
            positional_constraint = "CONTAINS"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "../"
            positional_constraint = "CONTAINS"
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "://"
            positional_constraint = "CONTAINS"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "://"
            positional_constraint = "CONTAINS"
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}bytematchtraversal"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}bytematchtraversalgroup"
    sampled_requests_enabled   = true
  }
}

# Server-Side Includes & Libraries in Webroot
resource "aws_wafv2_rule_group" "byte_set_webroot_requests" {
  name     = "${var.stage}_${var.region}_${var.api_name}_byte_match_webroot_requests"
  scope    = "REGIONAL"
  capacity = 50
  count    = var.enabled

  rule {
    name     = "webroot_rule"
    priority = 1

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          byte_match_statement {
            search_string         = ".cfg"
            positional_constraint = "ENDS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = ".conf"
            positional_constraint = "ENDS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = ".config"
            positional_constraint = "ENDS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = ".ini"
            positional_constraint = "ENDS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = ".log"
            positional_constraint = "ENDS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = ".bak"
            positional_constraint = "ENDS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = ".backup"
            positional_constraint = "ENDS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "/includes"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "/admin"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}bytematchwebroot"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}bytematchwebrootgroup"
    sampled_requests_enabled   = true
  }
}

# Web ACL
resource "aws_wafv2_web_acl" "web_acl" {
  name  = "${var.stage}_${var.region}_${var.api_name}_web_acl"
  scope = "REGIONAL"
  count = var.enabled

  default_action {
    dynamic "allow" {
      for_each = var.web_acl_default_action == "ALLOW" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.web_acl_default_action == "BLOCK" ? [1] : []
      content {}
    }
  }

  rule {
    name     = "ip_blacklist"
    priority = 10

    action {
      dynamic "block" {
        for_each = var.ip_blacklist_default_action == "BLOCK" ? [1] : []
        content {}
      }
      dynamic "count" {
        for_each = var.ip_blacklist_default_action == "COUNT" ? [1] : []
        content {}
      }
      dynamic "allow" {
        for_each = var.ip_blacklist_default_action == "ALLOW" ? [1] : []
        content {}
      }
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.iplist_blacklist[count.index].arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}ipblacklist"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate_ip_throttle"
    priority = 20

    action {
      dynamic "block" {
        for_each = var.rate_ip_throttle_default_action == "BLOCK" ? [1] : []
        content {}
      }
      dynamic "count" {
        for_each = var.rate_ip_throttle_default_action == "COUNT" ? [1] : []
        content {}
      }
      dynamic "allow" {
        for_each = var.rate_ip_throttle_default_action == "ALLOW" ? [1] : []
        content {}
      }
    }

    statement {
      rate_based_statement {
        limit              = var.rate_ip_throttle_limit
        aggregate_key_type = "IP"
        scope_down_statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.iplist_throttle[count.index].arn
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}ipthrottle"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "xss_match_rule"
    priority = 30

    action {
      dynamic "block" {
        for_each = var.xss_match_rule_default_action == "BLOCK" ? [1] : []
        content {}
      }
      dynamic "count" {
        for_each = var.xss_match_rule_default_action == "COUNT" ? [1] : []
        content {}
      }
      dynamic "allow" {
        for_each = var.xss_match_rule_default_action == "ALLOW" ? [1] : []
        content {}
      }
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.xss_match_conditions[count.index].arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}xssmatchrule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "sql_injection_rule"
    priority = 40

    action {
      dynamic "block" {
        for_each = var.sql_injection_default_action == "BLOCK" ? [1] : []
        content {}
      }
      dynamic "count" {
        for_each = var.sql_injection_default_action == "COUNT" ? [1] : []
        content {}
      }
      dynamic "allow" {
        for_each = var.sql_injection_default_action == "ALLOW" ? [1] : []
        content {}
      }
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.sql_injection_match_set[count.index].arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}sqlinjectionrule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "byte_match_traversal"
    priority = 50

    action {
      dynamic "block" {
        for_each = var.byte_match_traversal_default_action == "BLOCK" ? [1] : []
        content {}
      }
      dynamic "count" {
        for_each = var.byte_match_traversal_default_action == "COUNT" ? [1] : []
        content {}
      }
      dynamic "allow" {
        for_each = var.byte_match_traversal_default_action == "ALLOW" ? [1] : []
        content {}
      }
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.byte_set_traversal[count.index].arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}bytematchtraversalrule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "byte_match_webroot"
    priority = 60

    action {
      dynamic "block" {
        for_each = var.byte_match_webroot_default_action == "BLOCK" ? [1] : []
        content {}
      }
      dynamic "count" {
        for_each = var.byte_match_webroot_default_action == "COUNT" ? [1] : []
        content {}
      }
      dynamic "allow" {
        for_each = var.byte_match_webroot_default_action == "ALLOW" ? [1] : []
        content {}
      }
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.byte_set_webroot_requests[count.index].arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}bytematchwebrootrule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${replace(var.stage, "/[^a-zA-Z0-9]/", "")}${replace(var.region, "/[^a-zA-Z0-9]/", "")}${replace(var.api_name, "/[^a-zA-Z0-9]/", "")}rmswebacl"
    sampled_requests_enabled   = true
  }
}

# Web ACL Association
resource "aws_wafv2_web_acl_association" "web_acl_association" {
  resource_arn = var.acl_association_resource_arn
  web_acl_arn  = aws_wafv2_web_acl.web_acl[count.index].arn
  count        = var.enabled
}