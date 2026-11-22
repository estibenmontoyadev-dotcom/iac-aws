variable "project_name" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "aws_region" {
  description = "Region de AWS (las metricas de Route 53 solo existen en us-east-1)"
  type        = string
}

variable "alert_emails" {
  description = "Correos que reciben las alertas (cada uno debe confirmar la suscripcion de SNS)"
  type        = list(string)
}

# ---------- Recursos observados ----------
variable "alb_dns_name" {
  description = "DNS del ALB, destino de la comprobacion de disponibilidad"
  type        = string
}

variable "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (dimension LoadBalancer)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Sufijo del ARN del grupo de destino (dimension TargetGroup)"
  type        = string
}

variable "cluster_name" {
  description = "Nombre del cluster ECS"
  type        = string
}

variable "service_name" {
  description = "Nombre del servicio ECS"
  type        = string
}

variable "service_arn" {
  description = "ARN del servicio ECS (filtro de los eventos de despliegue)"
  type        = string
}

variable "log_group_name" {
  description = "Grupo de logs del contenedor"
  type        = string
}

variable "db_instance_identifier" {
  description = "Identificador de la instancia RDS"
  type        = string
}

variable "cache_cluster_id" {
  description = "ID del nodo de ElastiCache (CacheClusterId)"
  type        = string
}

variable "uptime_path" {
  description = "Ruta que consulta la comprobacion de disponibilidad"
  type        = string
  default     = "/"
}

# ---------- Umbrales de las alertas ----------
variable "alb_5xx_percent_threshold" {
  description = "Porcentaje de respuestas 5xx del backend que dispara la alerta"
  type        = number
  default     = 5
}

variable "latency_p95_seconds_threshold" {
  description = "Latencia p95 del backend (segundos) que dispara la alerta"
  type        = number
  default     = 2
}

variable "ecs_cpu_threshold" {
  description = "Porcentaje de CPU del servicio ECS que dispara la alerta"
  type        = number
  default     = 80
}

variable "ecs_memory_threshold" {
  description = "Porcentaje de memoria del servicio ECS que dispara la alerta"
  type        = number
  default     = 85
}

variable "php_fatal_errors_threshold" {
  description = "Errores fatales de PHP en 5 minutos que disparan la alerta"
  type        = number
  default     = 5
}

variable "db_cpu_threshold" {
  description = "Porcentaje de CPU de RDS que dispara la alerta"
  type        = number
  default     = 80
}

variable "db_free_storage_bytes_threshold" {
  description = "Espacio libre de RDS (bytes) por debajo del cual se dispara la alerta"
  type        = number
  default     = 2147483648 # 2 GiB de 20 GiB asignados
}

variable "db_freeable_memory_bytes_threshold" {
  description = "Memoria liberable de RDS (bytes) por debajo de la cual se dispara la alerta"
  type        = number
  default     = 104857600 # 100 MiB
}

variable "db_connections_threshold" {
  description = "Conexiones abiertas a RDS que disparan la alerta (db.t4g.micro admite unas 85)"
  type        = number
  default     = 60
}

variable "cache_cpu_threshold" {
  description = "Porcentaje de CPU del motor de Valkey que dispara la alerta"
  type        = number
  default     = 80
}

variable "cache_memory_threshold" {
  description = "Porcentaje de memoria de Valkey que dispara la alerta"
  type        = number
  default     = 85
}

variable "cache_hit_ratio_threshold" {
  description = "Porcentaje de aciertos de Valkey por debajo del cual se dispara la alerta"
  type        = number
  default     = 70
}
