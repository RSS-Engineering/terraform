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

# Rate throttle IP Range(s)
# Must be in CIDR format
variable "iplist_throttle_CIDR_0" {
  type    = string
  default = "0.0.0.0/32"
}

# Enable or disable the WAF deployment
# Set to 0 by default to ensure intentional deployment
variable "enabled" {
  type    = number
  default = 0
}