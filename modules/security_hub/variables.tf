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
