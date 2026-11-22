terraform {
  required_version = ">= 1.10.0" # use_lockfile (bloqueo del estado en S3) requiere 1.10 o superior

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
