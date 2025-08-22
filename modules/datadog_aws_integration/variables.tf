variable "host_tags" {
  type        = map(string)
  description = "Tags to be added to all metrics read through this integration"

  default = {}
}

variable "included_namespaces" {
  type        = list(string)
  description = "List of AWS namespaces to include in the integration"

  default = []
}