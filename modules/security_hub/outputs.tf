output "security_hub" {
  value = aws_securityhub_account.security_hub
}

output "disabled_securityhub_controls" {
  value = var.disabled_securityhub_controls
}
