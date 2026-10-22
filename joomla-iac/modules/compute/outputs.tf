output "joomla_url" {
  description = "URL to access the Joomla site"
  value       = "http://${aws_eip.joomla.public_ip}"
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.joomla.id
}

output "public_ip" {
  description = "Elastic IP of the instance"
  value       = aws_eip.joomla.public_ip
}
