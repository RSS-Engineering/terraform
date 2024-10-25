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

variable "redeployment_hash" {
  type    = string
  default = ""
}

variable "log_retention_in_days" {
  type    = number
  default = 0
  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_in_days)
    error_message = "Must be one of 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653 or 0 for never expire."
  }
}

variable "endpoint_type" {
  type    = string
  default = "EDGE"

  validation {
    condition     = var.endpoint_type == "REGIONAL" || var.endpoint_type == "EDGE"
    error_message = "Must be \"REGIONAL\" or \"EDGE\"."
  }
}

variable "authorizers" {
  type    = map(map(string))
  default = {}
}

variable "lambdas" {
  type = map(map(string))
}


variable "routes" {
  type = map(map(string))
}

variable "set_cloudwatch_role" {
  type = bool

  default = true
}

variable "apigateway_cloudwatch_role_arn" {
  type = string

  default = ""
}

variable "binary_media_types" {
  type    = list()
  default = []
}
