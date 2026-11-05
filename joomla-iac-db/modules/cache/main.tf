resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-cache-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-cache-subnets"
  }
}

# Valkey: motor en memoria compatible con Redis. Joomla lo usa para sesiones y cache.
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project_name}-valkey"
  description          = "Cache y sesiones de Joomla (${var.project_name})"

  engine               = "valkey"
  engine_version       = "8.0"
  parameter_group_name = "default.valkey8"
  node_type            = var.node_type
  port                 = 6379

  num_cache_clusters         = 1
  automatic_failover_enabled = false

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.security_group_id]

  at_rest_encryption_enabled = true
  # El cliente PHP de Joomla se conecta sin TLS; el acceso queda limitado por Security Group
  # y la subred privada. Para produccion: habilitar TLS y usar tls:// en el host.
  transit_encryption_enabled = false

  apply_immediately = true

  tags = {
    Name = "${var.project_name}-valkey"
  }
}
