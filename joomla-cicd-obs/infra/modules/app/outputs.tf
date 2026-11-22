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

output "service_arn" {
  description = "ARN del servicio ECS"
  value       = aws_ecs_service.joomla.id
}

output "task_definition_family" {
  description = "Familia de la definicion de tarea (el pipeline registra revisiones nuevas)"
  value       = aws_ecs_task_definition.joomla.family
}

output "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (dimension LoadBalancer de CloudWatch)"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Sufijo del ARN del grupo de destino (dimension TargetGroup de CloudWatch)"
  value       = aws_lb_target_group.joomla.arn_suffix
}
