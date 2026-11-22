output "joomla_url" {
  description = "URL publica del sitio (balanceador de carga)"
  value       = module.app.joomla_url
}

output "alb_dns_name" {
  description = "DNS del Application Load Balancer"
  value       = module.app.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = module.app.cluster_name
}

output "ecs_service_name" {
  description = "Nombre del servicio ECS"
  value       = module.app.service_name
}

output "task_definition_family" {
  description = "Familia de la definicion de tarea que actualiza el pipeline de la aplicacion"
  value       = module.app.task_definition_family
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos relacional (RDS MySQL)"
  value       = module.database.address
}

output "cache_endpoint" {
  description = "Endpoint de la base de datos en memoria (ElastiCache Valkey)"
  value       = module.cache.address
}

output "efs_file_system_id" {
  description = "Sistema de archivos EFS con el sitio Joomla"
  value       = module.storage.file_system_id
}

output "dashboard_url" {
  description = "Dashboard de CloudWatch"
  value       = module.monitoring.dashboard_url
}

output "alerts_topic_arn" {
  description = "Topico SNS de las alertas"
  value       = module.monitoring.sns_topic_arn
}

output "logs_command" {
  description = "Comando para seguir los logs del contenedor"
  value       = "aws logs tail ${module.app.log_group_name} --follow --region ${var.aws_region}"
}
