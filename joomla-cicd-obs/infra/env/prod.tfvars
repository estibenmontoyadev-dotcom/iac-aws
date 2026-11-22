# Valores NO secretos del ambiente. Se versiona en git y lo leen los pipelines.
# Las contrasenas nunca van aqui: el pipeline entrega admin_password desde Secrets Manager.
aws_region   = "us-east-1"
project_name = "joomla-cicd"

# Red
vpc_cidr           = "10.3.0.0/16"
az_count           = 2
http_allowed_cidrs = ["0.0.0.0/0"]

# Bases de datos
db_instance_class = "db.t4g.micro"
db_name           = "joomladb"
db_username       = "joomla_admin"
db_multi_az       = false
cache_node_type   = "cache.t4g.micro"

# Contenedor
task_cpu           = 512
task_memory        = 1024
desired_count      = 1
log_retention_days = 14

# Joomla
site_name      = "Sitio Joomla CI/CD y Observabilidad"
admin_username = "admin_itm"
admin_email    = "estibenmontoya190768@correo.itm.edu.co"

# Observabilidad: cada correo debe confirmar la suscripcion de SNS que le llega
alert_emails = ["estibenmontoya190768@correo.itm.edu.co"]
