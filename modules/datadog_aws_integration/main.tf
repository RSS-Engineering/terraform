data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Adapted from https://docs.datadoghq.com/integrations/guide/aws-terraform-setup/

locals {
  integration_role_name = "DatadogAWSIntegrationRole"
}

data "aws_iam_policy_document" "integration_policy_document" {
  statement {
    actions = [
      "xray:GetTraceSummaries",
      "xray:BatchGetTraces",
      "tag:GetTagValues",
      "tag:GetTagKeys",
      "tag:GetResources",
      "support:*",
      "sqs:ListQueues",
      "sns:Publish",
      "sns:List*",
      "ses:Get*",
      "s3:PutBucketNotification",
      "s3:ListAllMyBuckets",
      "s3:GetBucketTagging",
      "s3:GetBucketNotification",
      "s3:GetBucketLogging",
      "s3:GetBucketLocation",
      "route53:List*",
      "redshift:DescribeLoggingStatus",
      "redshift:DescribeClusters",
      "rds:List*",
      "rds:Describe*",
      "logs:TestMetricFilter",
      "logs:PutSubscriptionFilter",
      "logs:Get*",
      "logs:FilterLogEvents",
      "logs:DescribeSubscriptionFilters",
      "logs:Describe*",
      "logs:DeleteSubscriptionFilter",
      "lambda:RemovePermission",
      "lambda:List*",
      "lambda:GetPolicy",
      "lambda:AddPermission",
      "kinesis:List*",
      "kinesis:Describe*",
      "health:DescribeEvents",
      "health:DescribeEventDetails",
      "health:DescribeAffectedEntities",
      "es:ListTags",
      "es:ListDomainNames",
      "es:DescribeElasticsearchDomains",
      "elasticmapreduce:List*",
      "elasticmapreduce:Describe*",
      "elasticloadbalancing:Describe*",
      "elasticfilesystem:DescribeTags",
      "elasticfilesystem:DescribeFileSystems",
      "elasticache:List*",
      "elasticache:Describe*",
      "ecs:List*",
      "ecs:Describe*",
      "ec2:Describe*",
      "dynamodb:List*",
      "dynamodb:Describe*",
      "directconnect:Describe*",
      "codedeploy:List*",
      "codedeploy:BatchGet*",
      "cloudwatch:List*",
      "cloudwatch:Get*",
      "cloudwatch:Describe*",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:DescribeTrails",
      "cloudfront:ListDistributions",
      "cloudfront:GetDistributionConfig",
      "budgets:ViewBudget",
      "autoscaling:Describe*",
      "apigateway:GET"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "integration_policy" {
  name = "DatadogAWSIntegrationPolicy"
  path = "/"

  policy = data.aws_iam_policy_document.integration_policy_document.json
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::464622532012:root", # Datadog's AWS account
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values = [
        datadog_integration_aws.integration.external_id
      ]
    }
  }
}

resource "aws_iam_role" "integration_role" {
  name        = local.integration_role_name
  description = "Role for Datadog AWS Integration"

  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach_integration_policy" {
  role       = aws_iam_role.integration_role.name
  policy_arn = aws_iam_policy.integration_policy.arn
}

resource "datadog_integration_aws" "integration" {
  account_id = data.aws_caller_identity.current.account_id
  role_name  = local.integration_role_name
  host_tags = [
    for k, v in var.host_tags : "${k}:${v}"
  ]
  account_specific_namespace_rules = var.namespace_rules
}
