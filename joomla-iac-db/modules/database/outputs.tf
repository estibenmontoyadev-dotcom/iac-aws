output "address" {
  description = "Hostname de RDS (sin puerto)"
  value       = aws_db_instance.main.address
}

output "db_name" {
  description = "Nombre de la base de datos"
  value       = aws_db_instance.main.db_name
}

output "username" {
  description = "Usuario administrador"
  value       = aws_db_instance.main.username
}

output "master_secret_arn" {
  description = "ARN del secreto de Secrets Manager con las credenciales"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
