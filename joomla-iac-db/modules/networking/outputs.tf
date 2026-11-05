output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs de las subredes publicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas"
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "Security Group del balanceador"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security Group de los contenedores"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security Group de RDS"
  value       = aws_security_group.db.id
}

output "cache_security_group_id" {
  description = "Security Group de ElastiCache"
  value       = aws_security_group.cache.id
}
