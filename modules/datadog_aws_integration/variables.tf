variable "app_key" {
  type        = string
  description = "Datadog integration app key"
}

variable "api_key" {
  type        = string
  description = "Datadog integration API key"

  sensitive = true
}

variable "host_tags" {
  type        = map(string)
  description = "Tags to be added to all metrics read through this integration"

  default = {}
}
