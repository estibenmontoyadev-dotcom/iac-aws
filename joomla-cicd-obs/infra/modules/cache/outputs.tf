output "address" {
  description = "Endpoint primario de Valkey"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "port" {
  description = "Puerto de Valkey"
  value       = aws_elasticache_replication_group.main.port
}

output "replication_group_id" {
  description = "ID del grupo de replicacion"
  value       = aws_elasticache_replication_group.main.replication_group_id
}

output "cache_cluster_id" {
  description = "ID del nodo (dimension CacheClusterId de las metricas de CloudWatch)"
  value       = tolist(aws_elasticache_replication_group.main.member_clusters)[0]
}
