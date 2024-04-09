variable "resource_prefix" {
  type = string
}
variable "resource_path" {
  type = string
}
variable "lambda_runtime" {
  type = string
}
variable "private_subnet_ids" {
  type = list(any)
}
variable "security_group_ids" {
  type = list(any)
}
variable "service_account_secret_arn" {
  type = string
}
variable "use_janus_proxy" {
  type = bool
  default = true
}
variable "rotation_schedule_expression" {
  type = string
  default = "rate(4 hours)"
}