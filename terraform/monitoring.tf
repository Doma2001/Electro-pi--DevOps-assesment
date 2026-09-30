resource "aws_cloudwatch_metric_alarm" "backend_cpu" {
  alarm_name          = "${var.project_name}-backend-high-cpu"
  alarm_description   = "Average ECS backend CPU above 80% for 5 minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  tags = {
    Name = "${var.project_name}-backend-high-cpu"
  }
}
