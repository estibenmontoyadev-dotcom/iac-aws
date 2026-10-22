output "joomla_url" {
  description = "URL to access the Joomla site"
  value       = module.compute.joomla_url
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "Elastic IP of the Joomla instance"
  value       = module.compute.public_ip
}

output "ssm_connect_command" {
  description = "Command to open a shell on the instance through SSM Session Manager"
  value       = "aws ssm start-session --target ${module.compute.instance_id} --region ${var.aws_region}"
}

output "vpc_id" {
  description = "ID of the VPC created"
  value       = module.networking.vpc_id
}
