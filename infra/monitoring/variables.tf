variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ntc-constellation"
}

variable "environment" {
  description = "Env tag"
  type        = string
  default     = "dev"
}

variable "alarm_error_rate_threshold" {
  description = "5xx error rate percentage to alarm"
  type        = number
  default     = 5
}

variable "alarm_evaluation_periods" {
  description = "Number of consecutive periods"
  type        = number
  default     = 2
}

variable "alarm_period_seconds" {
  description = "Length of each evaluation period in seconds"
  type        = number
  default     = 60
}
