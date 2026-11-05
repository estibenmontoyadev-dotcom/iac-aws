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

output "rds_endpoint" {
  description = "Endpoint de la base de datos relacional (RDS MySQL)"
  value       = module.database.address
}

output "cache_endpoint" {
  description = "Endpoint de la base de datos en memoria (ElastiCache Valkey)"
  value       = module.cache.address
}

output "db_secret_arn" {
  description = "ARN del secreto en Secrets Manager con la contrasena de RDS"
  value       = module.database.master_secret_arn
}

output "logs_command" {
  description = "Comando para seguir los logs del contenedor"
  value       = "aws logs tail ${module.app.log_group_name} --follow --region ${var.aws_region}"
}

output "ecs_exec_command" {
  description = "Comando para abrir una shell en el contenedor (ECS Exec, sin SSH). Reemplazar <TASK_ID>"
  value       = "aws ecs execute-command --cluster ${module.app.cluster_name} --task <TASK_ID> --container joomla --interactive --command /bin/bash --region ${var.aws_region}"
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = module.networking.vpc_id
}
