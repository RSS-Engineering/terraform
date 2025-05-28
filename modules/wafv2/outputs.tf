output "web_acl_arn" {
  description = "The ARN of the WAFv2 Web ACL"
  value       = var.enabled == 1 ? one(aws_wafv2_web_acl.web_acl[*].arn) : ""
}

output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for WAFv2 logs"
  value       = var.enabled == 1 ? one(aws_cloudwatch_log_group.web_acl_log[*].arn) : ""
}