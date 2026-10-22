variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project, used as prefix for resource names"
  type        = string
  default     = "joomla-ec2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "http_allowed_cidrs" {
  description = "CIDR blocks allowed to reach Joomla over HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Size in GB of the root EBS volume"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the Joomla database"
  type        = string
  default     = "joomladb"
}

variable "db_username" {
  description = "Username for the Joomla database"
  type        = string
  default     = "joomla_user"
}

variable "db_password" {
  description = "Password for the Joomla database"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12 && !can(regex("['\"\\\\$`]", var.db_password))
    error_message = "db_password must be at least 12 characters and must not contain quotes, backslashes, backticks or $."
  }
}

variable "joomla_version" {
  description = "Joomla version to download from the official GitHub releases"
  type        = string
  default     = "6.1.2"
}

variable "site_name" {
  description = "Name of the Joomla site"
  type        = string
  default     = "Sitio Joomla IaC"
}

variable "admin_username" {
  description = "Joomla super user login"
  type        = string
  default     = "admin_itm"
}

variable "admin_email" {
  description = "Joomla super user email"
  type        = string
  default     = "admin@example.com"
}

variable "admin_password" {
  description = "Joomla super user password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12 && !can(regex("['\"\\\\$`]", var.admin_password))
    error_message = "admin_password must be at least 12 characters and must not contain quotes, backslashes, backticks or $."
  }
}
