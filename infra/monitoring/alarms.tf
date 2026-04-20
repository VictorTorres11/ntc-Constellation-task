# CloudWatch alarms for ALB monitoring
# Reference: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html
# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm

locals {
  alb_arn_suffix = data.aws_lb.this.arn_suffix
}

# Fires when 5xx rate exceeds the threshold for N consecutive 1-minute periods.
# Uses a math expression so the alarm stays silent when there's no traffic.
resource "aws_cloudwatch_metric_alarm" "alb_5xx_rate" {
  alarm_name          = "${var.project_name}-alb-5xx-rate"
  alarm_description   = "5xx error rate above ${var.alarm_error_rate_threshold}% for ${var.alarm_evaluation_periods} consecutive minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = var.alarm_error_rate_threshold
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "IF(requests > 0, (errors / requests) * 100, 0)"
    label       = "5xx Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_ELB_5XX_Count"
      period      = var.alarm_period_seconds
      stat        = "Sum"
      dimensions = {
        LoadBalancer = local.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = var.alarm_period_seconds
      stat        = "Sum"
      dimensions = {
        LoadBalancer = local.alb_arn_suffix
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-alb-5xx-rate"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
