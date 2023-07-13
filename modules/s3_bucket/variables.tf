variable "name" {
  type        = string
  description = "name of the bucket"
}

variable "bucket_policies" {
  type        = list(string)
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
