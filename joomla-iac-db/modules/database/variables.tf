variable "project_name" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subredes privadas donde vive RDS"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group de RDS"
  type        = string
}

variable "instance_class" {
  description = "Clase de instancia de RDS"
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}

variable "db_username" {
  description = "Usuario administrador"
  type        = string
}

variable "multi_az" {
  description = "Despliegue Multi-AZ"
  type        = bool
}
