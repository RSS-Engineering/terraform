variable "log_sources" {
  type = set(object({
    bucket_name     = string,
    expiration_days = optional(number, 400)
  }))
  description = "list of bucket names to enable logging for"
}

variable "default_expiration_days" {
  type        = number
  default     = 400
  description = "number of days to keep logs for, defaults to `400`"
}

variable "bucket_name" {
  type        = string
  description = "name of the logging destination bucket to be created"
}
