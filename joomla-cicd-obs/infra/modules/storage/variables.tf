variable "project_name" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "subnet_ids" {
  description = "Subredes donde se crean los puntos de montaje (una por zona de disponibilidad)"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group de EFS"
  type        = string
}
