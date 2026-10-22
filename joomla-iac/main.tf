provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  http_allowed_cidrs = var.http_allowed_cidrs
}

module "compute" {
  source = "./modules/compute"

  project_name      = var.project_name
  subnet_id         = module.networking.public_subnet_id
  security_group_id = module.networking.web_security_group_id

  instance_type    = var.instance_type
  root_volume_size = var.root_volume_size

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  joomla_version = var.joomla_version
  site_name      = var.site_name
  admin_username = var.admin_username
  admin_email    = var.admin_email
  admin_password = var.admin_password
}
