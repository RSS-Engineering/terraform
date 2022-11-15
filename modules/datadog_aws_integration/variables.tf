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

variable "namespace_rules" {
  # https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/integration_aws#account_specific_namespace_rules
  type = map(bool)
  description = "Enables or disables metric collection for specific AWS namespaces for this AWS account only"

  default = {}
}
