variable "instance" {
  type        = string
  description = "Which Security Hub instance to accept invitations from: e.g. `dev` or `prod`. Leave blank to not accept invitations."
}

variable "admin_account" {
  type        = map(string)
  description = "Map of AWS Account IDs for the Security Hub Admin Accounts, keyed on instance."

  default = {
    dev  = "152267171281"
    prod = "636967684097"
  }
}

variable "disabled_securityhub_controls" {
  type = list(string)
  description = "List of Security Hub controls to disable"
  default = [
    "arn:aws:securityhub:::ruleset/aws-foundational-security-best-practices/v/1.0.0/Config.1",
    "arn:aws:securityhub:::ruleset/aws-foundational-security-best-practices/v/1.0.0/IAM.6",
    "arn:aws:securityhub:::ruleset/aws-foundational-security-best-practices/v/1.0.0/Inspector.1",
    "arn:aws:securityhub:::ruleset/aws-foundational-security-best-practices/v/1.0.0/GuardDuty.5",
    "arn:aws:securityhub:::ruleset/aws-foundational-security-best-practices/v/1.0.0/GuardDuty.8"
  ]
}
