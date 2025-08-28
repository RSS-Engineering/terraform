variable "tags" {
  description = "A list of tags to to apply to all metrics in the account."
  type        = list(string)
  default     = []
}

variable "excluded_metrics" {
  description = "A list of metrics to exclude in the integration."
  type        = list(string)
  default     = ["AWS/SQS", "AWS/ElasticMapReduce"]
}

variable "app_key" {
  description = "The Datadog application key."
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "The Datadog API key."
  type        = string
  sensitive   = true
}
