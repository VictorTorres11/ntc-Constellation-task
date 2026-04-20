# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Latency"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_arn_suffix, { stat = "p50", label = "P50" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_arn_suffix, { stat = "p95", label = "P95" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_arn_suffix, { stat = "p99", label = "P99" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB 5xx Error Rate"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            [{ expression = "IF(requests > 0, (errors / requests) * 100, 0)", label = "5xx Rate (%)", id = "error_rate" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.alb_arn_suffix, { id = "errors", visible = false }],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_arn_suffix, { id = "requests", visible = false }]
          ]
          annotations = {
            horizontal = [
              {
                label = "Threshold ${var.alarm_error_rate_threshold}%"
                value = var.alarm_error_rate_threshold
                color = "#ff0000"
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_arn_suffix, { stat = "Sum", label = "Total" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", local.alb_arn_suffix, { stat = "Sum", label = "2xx" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.alb_arn_suffix, { stat = "Sum", label = "5xx" }]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Alarm Status"
          alarms = [aws_cloudwatch_metric_alarm.alb_5xx_rate.arn]
        }
      }
    ]
  })
}
