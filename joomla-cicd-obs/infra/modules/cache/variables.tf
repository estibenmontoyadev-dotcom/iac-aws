variable "project_name" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subredes privadas donde vive ElastiCache"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group de ElastiCache"
  type        = string
}

variable "node_type" {
  description = "Tipo de nodo"
  type        = string
}
