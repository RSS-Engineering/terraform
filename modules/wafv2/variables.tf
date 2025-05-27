variable "stage" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = ""
}

variable "acl_association_resource_arn" {
  type    = string
  default = ""
}

variable "api_name" {
  type    = string
  default = ""
}

# Valid values are BLOCK or ALLOW
# The correct setting is almost always ALLOW
variable "web_acl_default_action" {
  type    = string
  default = "ALLOW"
}

# Valid values are BLOCK, ALLOW, COUNT
# BLOCK will typically be the correct production value
# Default is COUNT to make BLOCK or ALLOW an intentional decision
variable "ip_blacklist_default_action" {
  type    = string
  default = "COUNT"
}

variable "rate_ip_throttle_default_action" {
  type    = string
  default = "COUNT"
}

variable "xss_match_rule_default_action" {
  type    = string
  default = "COUNT"
}

variable "byte_match_traversal_default_action" {
  type    = string
  default = "COUNT"
}

variable "byte_match_webroot_default_action" {
  type    = string
  default = "COUNT"
}

variable "sql_injection_default_action" {
  type    = string
  default = "COUNT"
}

# Rate throttle IP Range(s)
# Must be in CIDR format
variable "iplist_throttle_CIDR_0" {
  type    = string
  default = "0.0.0.0/32"
}

# Requests per 5 minutes
variable "rate_ip_throttle_limit" {
  type    = number
  default = 5000
}

# Enable or disable the WAF deployment
# Set to 0 by default to ensure intentional deployment
variable "enabled" {
  type    = number
  default = 0
}