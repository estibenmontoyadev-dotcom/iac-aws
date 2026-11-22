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

# 4) Almacenamiento del sitio: Amazon EFS (sobrevive a cada despliegue)
module "storage" {
  source = "./modules/storage"

  project_name      = var.project_name
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.efs_security_group_id
}

# 5) Servicio contenerizado: ECS Fargate detras de un Application Load Balancer
module "app" {
  source = "./modules/app"

  project_name          = var.project_name
  aws_region            = var.aws_region
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  app_security_group_id = module.networking.app_security_group_id

  container_image    = var.container_image
  efs_file_system_id = module.storage.file_system_id
  log_retention_days = var.log_retention_days
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  desired_count      = var.desired_count

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

  # La tarea monta EFS al arrancar: los puntos de montaje deben existir antes
  depends_on = [module.storage]
}

# 6) Observabilidad: dashboard, alarmas, canal de notificacion y comprobacion de disponibilidad
module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  aws_region   = var.aws_region
  alert_emails = var.alert_emails

  alb_dns_name            = module.app.alb_dns_name
  alb_arn_suffix          = module.app.alb_arn_suffix
  target_group_arn_suffix = module.app.target_group_arn_suffix
  cluster_name            = module.app.cluster_name
  service_name            = module.app.service_name
  service_arn             = module.app.service_arn
  log_group_name          = module.app.log_group_name

  db_instance_identifier = module.database.identifier
  cache_cluster_id       = module.cache.cache_cluster_id
}
