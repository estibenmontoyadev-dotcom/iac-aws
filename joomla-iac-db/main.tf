provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

# 1) Red: VPC, subredes publicas/privadas y Security Groups encadenados
module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  http_allowed_cidrs = var.http_allowed_cidrs
}

# 2) Persistencia relacional gestionada: Amazon RDS (MySQL)
module "database" {
  source = "./modules/database"

  project_name       = var.project_name
  private_subnet_ids = module.networking.private_subnet_ids
  security_group_id  = module.networking.db_security_group_id

  instance_class = var.db_instance_class
  db_name        = var.db_name
  db_username    = var.db_username
  multi_az       = var.db_multi_az
}

# 3) Persistencia en memoria gestionada: Amazon ElastiCache (Valkey)
module "cache" {
  source = "./modules/cache"

  project_name       = var.project_name
  private_subnet_ids = module.networking.private_subnet_ids
  security_group_id  = module.networking.cache_security_group_id

  node_type = var.cache_node_type
}

# 4) Servicio contenerizado: ECS Fargate detras de un Application Load Balancer
module "app" {
  source = "./modules/app"

  project_name          = var.project_name
  aws_region            = var.aws_region
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  app_security_group_id = module.networking.app_security_group_id

  joomla_image_tag = var.joomla_image_tag
  task_cpu         = var.task_cpu
  task_memory      = var.task_memory
  desired_count    = var.desired_count

  db_host                = module.database.address
  db_name                = module.database.db_name
  db_username            = module.database.username
  db_password_secret_arn = module.database.master_secret_arn

  cache_host = module.cache.address
  cache_port = module.cache.port

  site_name      = var.site_name
  admin_username = var.admin_username
  admin_email    = var.admin_email
  admin_password = var.admin_password
}
