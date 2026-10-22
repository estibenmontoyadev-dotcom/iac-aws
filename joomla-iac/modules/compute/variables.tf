variable "project_name" {
  description = "Name of the project, used as prefix for resource names"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the instance is launched"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group attached to the instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "root_volume_size" {
  description = "Size in GB of the root EBS volume"
  type        = number
}

variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "db_username" {
  description = "Username for the database"
  type        = string
}

variable "db_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
}

variable "joomla_version" {
  description = "Joomla version to install"
  type        = string
}

variable "site_name" {
  description = "Name of the Joomla site"
  type        = string
}

variable "admin_username" {
  description = "Joomla super user login"
  type        = string
}

variable "admin_email" {
  description = "Joomla super user email"
  type        = string
}

variable "admin_password" {
  description = "Joomla super user password"
  type        = string
  sensitive   = true
}
