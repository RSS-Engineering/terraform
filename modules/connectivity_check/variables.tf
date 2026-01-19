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

# Monitoring variables (defined in monitoring.tf but declared here for visibility)
variable "enable_monitoring" {
  description = "Enable scheduled monitoring and CloudWatch alarms"
  type        = bool
  default     = false
}

variable "monitoring_schedule" {
  description = "EventBridge schedule expression for monitoring (e.g., 'rate(5 minutes)')"
  type        = string
  default     = "rate(5 minutes)"
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

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs to send alarms to"
  type        = list(string)
  default     = []
}

variable "cloudwatch_namespace" {
  description = "CloudWatch namespace for custom metrics"
  type        = string
  default     = "janus/connectivity"
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarms"
  type        = number
  default     = 2
}
