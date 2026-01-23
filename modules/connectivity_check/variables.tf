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

# Monitoring variables
variable "enable_monitoring" {
  description = "Enable scheduled monitoring with Datadog metrics"
  type        = bool
  default     = false
}

variable "monitoring_schedule" {
  description = "EventBridge schedule expression for monitoring (e.g., 'rate(1 minute)')"
  type        = string
  default     = "rate(1 minute)"
}

variable "monitoring_targets" {
  description = "List of targets to monitor"
  type = list(object({
    host     = string
    port     = number
    protocol = string
    path     = optional(string)
    critical = optional(bool, false)
  }))
  default = []
}

variable "datadog_api_key" {
  description = "Datadog API key for publishing metrics (required when enable_monitoring = true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "janus_environment" {
  description = "Janus environment name (e.g., 'dev', 'prod')"
  type        = string
  default     = "unknown"
}
