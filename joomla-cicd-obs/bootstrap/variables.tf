variable "aws_region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo de los recursos. Debe ser el mismo project_name de infra/env/prod.tfvars"
  type        = string
  default     = "joomla-cicd"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name debe tener 3-21 caracteres: minusculas, numeros y guiones, iniciando con letra."
  }
}

variable "github_owner" {
  description = "Usuario u organizacion de GitHub duena del repositorio"
  type        = string
  default     = "estibenmontoyadev-dotcom"
}

variable "github_repo" {
  description = "Nombre del repositorio de GitHub donde viven los workflows"
  type        = string
  default     = "iac-aws"
}

variable "main_branch" {
  description = "Rama desde la que se despliega la aplicacion"
  type        = string
  default     = "main"
}

variable "github_environment" {
  description = "Entorno de GitHub que exige aprobacion para aplicar o destruir la infraestructura"
  type        = string
  default     = "production"
}

variable "create_github_oidc_provider" {
  description = "Crear el proveedor OIDC de GitHub. AWS admite uno solo por cuenta: usar false si ya existe"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Permite borrar el bucket de estado y el repositorio ECR aunque tengan contenido. Dejar en false salvo al eliminar el entorno por completo"
  type        = bool
  default     = false
}
