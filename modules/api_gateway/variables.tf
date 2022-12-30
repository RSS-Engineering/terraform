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

variable "lambdas" {
  type = map(map(string))
}

variable "root_route" {
  type = map(string)
}

variable "routes" {
  type = map(map(string))
}
