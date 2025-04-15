resource "aws_securityhub_account" "security_hub" {
  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

data "aws_region" "current" {}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.security_hub]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "pci" {
  depends_on    = [aws_securityhub_account.security_hub]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/pci-dss/v/4.0.1"
}

resource "aws_securityhub_product_subscription" "guardduty" {
  depends_on  = [aws_securityhub_account.security_hub]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/guardduty"
}

resource "aws_securityhub_invite_accepter" "invitee" {
  count      = var.instance == null ? 0 : 1
  depends_on = [aws_securityhub_account.security_hub]
  master_id  = var.admin_account[var.instance]
}
