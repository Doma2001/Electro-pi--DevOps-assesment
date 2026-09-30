output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.backend.name
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "backend_api_url" {
  value = "http://${aws_lb.app.dns_name}"
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "frontend_website_url" {
  value = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "database_secret_arn" {
  value     = aws_secretsmanager_secret.db.arn
  sensitive = true
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.app.name
}

output "cpu_alarm_name" {
  value = aws_cloudwatch_metric_alarm.backend_cpu.alarm_name
}
