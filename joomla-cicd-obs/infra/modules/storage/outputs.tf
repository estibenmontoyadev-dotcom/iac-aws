output "file_system_id" {
  description = "ID del sistema de archivos EFS"
  value       = aws_efs_file_system.main.id
}

output "mount_target_ids" {
  description = "IDs de los puntos de montaje (para declarar dependencias)"
  value       = aws_efs_mount_target.main[*].id
}
