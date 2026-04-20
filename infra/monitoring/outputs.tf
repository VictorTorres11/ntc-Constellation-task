output "alarm_5xx_rate_arn" {
  description = "ARN 5xx error rate alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx_rate.arn
}

output "alarm_5xx_rate_name" {
  description = "Name 5xx error rate alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx_rate.alarm_name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch dashboard ARN"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}
