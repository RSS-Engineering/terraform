variable "name" {
  type        = string
  description = "name of the bucket"
}

variable "bucket_policies" {
  type        = set(string)
  default     = []
  description = "list of additional bucket policies (as a json string) to attach to the bucket"
}

variable "enable_versioning" {
  type        = bool
  default     = false
  description = "whether or not to enable versioning, defaults to `false`"
}

variable "cloudfront_arns" {
  type        = set(string)
  default     = []
  description = "list of cloudfront distributions to allow read access to the bucket"
}

variable "expiration_days" {
  type        = number
  default     = null
  description = "number of days until objects expire, defaults to `null` for no expiration"
}

variable "noncurrent_expiration_days" {
  type        = number
  default     = null
  description = "number of days until noncurrent versions of objects expire, defaults to `null` for no expiration"
}

variable "additional_expiration_rules" {
  type = set(object({
    prefix                     = string
    expiration_days            = optional(number)
    noncurrent_expiration_days = optional(number)
  }))
  default     = []
  description = "additional expiration rules"

  validation {
    condition = alltrue([
      for rule in var.additional_expiration_rules : rule.expiration_days != null || rule.noncurrent_expiration_days != null
    ])
    error_message = "All expiration rules must specify either expiration_days or noncurrent_expiration_days"
  }
}

variable "tags" {
  type = map(string)

  default = {
    Terraform = "managed"
  }
}
