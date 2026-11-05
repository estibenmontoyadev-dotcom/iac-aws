output "address" {
  description = "Endpoint primario de Valkey"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "port" {
  description = "Puerto de Valkey"
  value       = aws_elasticache_replication_group.main.port
}
