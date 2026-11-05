variable "project_name" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "vpc_cidr" {
  description = "Rango CIDR de la VPC"
  type        = string
}

variable "az_count" {
  description = "Cantidad de zonas de disponibilidad"
  type        = number
}

variable "http_allowed_cidrs" {
  description = "CIDR con acceso HTTP al balanceador"
  type        = list(string)
}
