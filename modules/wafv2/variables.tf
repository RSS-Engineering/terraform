variable "stage" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = ""
}

# The Amazon Resource Name (ARN) of the resource to associate with the web ACL.
# This must be an ARN of an Application Load Balancer, an Amazon REST API Gateway stage
variable "acl_association_resource_arn" {
  type    = string
  default = ""
}

variable "service_name" {
  type    = string
  default = ""
}

# Enable or disable the WAF deployment
# Set to 0 by default to ensure intentional deployment doesn't occur
variable "enabled" {
  type    = number
  default = 0
}

variable "enable_xss_body_rule" {
  description = "Whether to enable the XSS body-only rule"
  type        = bool
  default     = false
}

# Specifies whether scope for an AWS CloudFront distribution(CLOUDFRONT) or for a
# regional application(REGIONAL)
variable "scope" {
  type    = string
  default = "REGIONAL"
}