variable "alarm_actions" {
  type    = list(string)
  default = []
}

variable "base_path" {
  type    = string
  default = ""
}

variable "binary_media_types" {
  type    = list(string)
  default = []
}

variable "custom_domain" {
  type    = string
  default = ""
}

variable "description" {
  type    = string
  default = ""
}

variable "enable_custom_domain" {
  type    = bool
  default = false
}

variable "enable_monitoring" {
  type    = bool
  default = false
}

variable "name" {
  description = "All-lowercase name of the API used in resource names"
}

variable "ok_actions" {
  type    = list(string)
  default = []
}

variable "stage" {
}

variable "openapi_template" {
}

variable "openapi_template_variables" {
  type    = map(string)
  default = {}
}

variable "xray_tracing_enabled" {
  type    = bool
  default = false
}

variable "zone_name" {
  type    = string
  default = ""
}
