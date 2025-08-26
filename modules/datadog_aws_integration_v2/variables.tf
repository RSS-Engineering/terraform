variable "tags" {
  description = "A list of tags to to apply to all metrics in the account."
  type        = list(string)
  default     = []
}

variable "included_metrics" {
  description = "A list of metrics to include in the integration."
  type        = list(string)
  default     = []
}