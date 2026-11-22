output "dashboard_url" {
  description = "URL del dashboard de CloudWatch"
  value       = local.dashboard_url
}

output "sns_topic_arn" {
  description = "ARN del topico de alertas"
  value       = aws_sns_topic.alerts.arn
}

output "health_check_id" {
  description = "ID de la comprobacion de disponibilidad de Route 53"
  value       = aws_route53_health_check.site.id
}

output "alarm_arns" {
  description = "ARN de todas las alarmas de CloudWatch del proyecto"
  value       = local.all_alarm_arns
}
