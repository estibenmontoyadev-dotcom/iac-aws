variable "project_name" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "aws_region" {
  description = "Region de AWS (para los logs)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "Subredes publicas para el ALB y las tareas"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security Group del ALB"
  type        = string
}

variable "app_security_group_id" {
  description = "Security Group de las tareas"
  type        = string
}

variable "joomla_image_tag" {
  description = "Tag de la imagen oficial de Joomla"
  type        = string
}

variable "task_cpu" {
  description = "CPU de la tarea Fargate"
  type        = number
}

variable "task_memory" {
  description = "Memoria de la tarea Fargate (MiB)"
  type        = number
}

variable "desired_count" {
  description = "Cantidad de tareas"
  type        = number
}

variable "db_host" {
  description = "Hostname de RDS"
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}

variable "db_username" {
  description = "Usuario de la base de datos"
  type        = string
}

variable "db_password_secret_arn" {
  description = "ARN del secreto de Secrets Manager con la contrasena de RDS"
  type        = string
}

variable "cache_host" {
  description = "Endpoint de ElastiCache"
  type        = string
}

variable "cache_port" {
  description = "Puerto de ElastiCache"
  type        = number
}

variable "site_name" {
  description = "Nombre del sitio Joomla"
  type        = string
}

variable "admin_username" {
  description = "Login del administrador de Joomla"
  type        = string
}

variable "admin_email" {
  description = "Correo del administrador de Joomla"
  type        = string
}

variable "admin_password" {
  description = "Contrasena del administrador de Joomla"
  type        = string
  sensitive   = true
}
