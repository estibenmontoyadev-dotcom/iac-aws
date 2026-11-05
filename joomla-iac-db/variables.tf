# ---------- General ----------
variable "aws_region" {
  description = "Region de AWS donde se crean los recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto, se usa como prefijo en los recursos"
  type        = string
  default     = "joomla-ecs"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name debe tener 3-21 caracteres: minusculas, numeros y guiones, iniciando con letra."
  }
}

# ---------- Red ----------
variable "vpc_cidr" {
  description = "Rango CIDR de la VPC (se divide en subredes /24)"
  type        = string
  default     = "10.2.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr debe ser un CIDR valido, por ejemplo 10.2.0.0/16."
  }
}

variable "az_count" {
  description = "Cantidad de zonas de disponibilidad a usar (el ALB y RDS exigen al menos 2)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count debe ser 2 o 3."
  }
}

variable "http_allowed_cidrs" {
  description = "CIDR que pueden llegar al balanceador por HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------- Base de datos relacional (RDS) ----------
variable "db_instance_class" {
  description = "Clase de instancia de RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Nombre de la base de datos de Joomla"
  type        = string
  default     = "joomladb"
}

variable "db_username" {
  description = "Usuario administrador de la base de datos (la contrasena la genera y guarda AWS Secrets Manager)"
  type        = string
  default     = "joomla_admin"
}

variable "db_multi_az" {
  description = "Activa la replica sincronica en otra zona (alta disponibilidad, duplica el costo)"
  type        = bool
  default     = false
}

# ---------- Base de datos en memoria (ElastiCache) ----------
variable "cache_node_type" {
  description = "Tipo de nodo de ElastiCache"
  type        = string
  default     = "cache.t4g.micro"
}

# ---------- Contenedor (ECS Fargate) ----------
variable "joomla_image_tag" {
  description = "Tag de la imagen oficial joomla en Docker Hub"
  type        = string
  default     = "6.2-php8.3-apache"
}

variable "task_cpu" {
  description = "CPU de la tarea Fargate (unidades: 256, 512, 1024...)"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memoria de la tarea Fargate en MiB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Cantidad de contenedores Joomla en ejecucion"
  type        = number
  default     = 1
}

# ---------- Joomla ----------
variable "site_name" {
  description = "Nombre del sitio Joomla"
  type        = string
  default     = "Sitio Joomla IaC - Contenedores y BD"
}

variable "admin_username" {
  description = "Usuario (login) del super administrador de Joomla"
  type        = string
  default     = "admin_itm"
}

variable "admin_email" {
  description = "Correo del super administrador de Joomla"
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.admin_email))
    error_message = "admin_email debe ser un correo valido."
  }
}

variable "admin_password" {
  description = "Contrasena del super administrador de Joomla (entregar con TF_VAR_admin_password)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12
    error_message = "admin_password debe tener al menos 12 caracteres (politica de Joomla)."
  }
}
