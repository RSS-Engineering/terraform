variable "subnet_ids" {
  description = "List of subnet IDs where the Lambda function will be deployed"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the Lambda function"
  type        = list(string)
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 10
}

variable "memory_size" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}
