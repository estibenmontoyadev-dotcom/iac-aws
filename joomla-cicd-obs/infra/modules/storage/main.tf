# Sistema de archivos compartido para el sitio Joomla.
# La imagen oficial de Joomla instala el sitio solo si no encuentra configuration.php;
# con el directorio web en EFS, un contenedor nuevo reutiliza el sitio ya instalado
# y no vuelve a ejecutar el instalador contra la base de datos.
resource "aws_efs_file_system" "main" {
  creation_token = "${var.project_name}-efs"
  encrypted      = true

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  # Los archivos sin uso pasan a una clase de almacenamiento mas barata
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.project_name}-efs"
  }
}

resource "aws_efs_mount_target" "main" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [var.security_group_id]
}

# Copias de seguridad automaticas con AWS Backup
resource "aws_efs_backup_policy" "main" {
  file_system_id = aws_efs_file_system.main.id

  backup_policy {
    status = "ENABLED"
  }
}
