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

variable "lambdas" {
  type = map(string)
}

variable "root_route" {
  type = map(string)
}

variable "routes" {
  type = map(map(string))
}
