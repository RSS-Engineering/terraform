variable "name" {
  type = string
}

variable "description" {
  type = string
}

variable "tags" {
  type = map(string)

  default = {
    Terraform = "managed"
  }
}

variable "stage_name" {
  type = string
}

variable "endpoint_type" {
  type = string
  default = "EDGE"

  validation {
    condition = var.endpoint_type == "REGIONAL" || var.endpoint_type == "EDGE"
    error_message = "Must be \"REGIONAL\" or \"EDGE\""
  }
}

variable "lambdas" {
  type = map(map(string))
}

variable "root_route" {
  type = map(string)
}

variable "routes" {
  type = map(map(string))
}
