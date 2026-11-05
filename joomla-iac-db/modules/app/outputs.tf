output "joomla_url" {
  description = "URL publica de Joomla"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "DNS del ALB"
  value       = aws_lb.main.dns_name
}

output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Nombre del servicio ECS"
  value       = aws_ecs_service.joomla.name
}

output "log_group_name" {
  description = "Grupo de logs de CloudWatch"
  value       = aws_cloudwatch_log_group.joomla.name
}
