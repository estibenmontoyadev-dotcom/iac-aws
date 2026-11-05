locals {
  # Joomla lee estos comandos al terminar su instalacion automatica (imagen oficial,
  # variable JOOMLA_CLI_COMMANDS) y deja sesiones y cache en ElastiCache (Valkey).
  joomla_cli_commands = join(" ", [
    "config:set",
    "session_handler=redis",
    "session_redis_server_host=${var.cache_host}",
    "session_redis_server_port=${var.cache_port}",
    "caching=1",
    "cache_handler=redis",
    "redis_server_host=${var.cache_host}",
    "redis_server_port=${var.cache_port}",
  ])
}

# ---------- Logs ----------
resource "aws_cloudwatch_log_group" "joomla" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs"
  }
}

# ---------- Secreto de la contrasena de Joomla ----------
resource "aws_secretsmanager_secret" "admin_password" {
  name                    = "${var.project_name}-joomla-admin-password"
  description             = "Contrasena del super administrador de Joomla"
  recovery_window_in_days = 0 # laboratorio: permite recrear el secreto tras un destroy

  tags = {
    Name = "${var.project_name}-joomla-admin-password"
  }
}

resource "aws_secretsmanager_secret_version" "admin_password" {
  secret_id     = aws_secretsmanager_secret.admin_password.id
  secret_string = var.admin_password
}

# ---------- IAM ----------
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Rol de ejecucion: lo usa ECS para bajar la imagen, escribir logs y leer secretos
resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = {
    Name = "${var.project_name}-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.db_password_secret_arn,
      aws_secretsmanager_secret.admin_password.arn,
    ]
  }
}

resource "aws_iam_role_policy" "read_secrets" {
  name   = "${var.project_name}-read-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_secrets.json
}

# Rol de la tarea: permisos del propio contenedor (solo ECS Exec, sin SSH)
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}

data "aws_iam_policy_document" "ecs_exec" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_exec" {
  name   = "${var.project_name}-ecs-exec"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.ecs_exec.json
}

# ---------- Cluster y definicion de la tarea ----------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

resource "aws_ecs_task_definition" "joomla" {
  family                   = "${var.project_name}-joomla"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "joomla"
      image     = "joomla:${var.joomla_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "JOOMLA_DB_HOST", value = var.db_host },
        { name = "JOOMLA_DB_NAME", value = var.db_name },
        { name = "JOOMLA_DB_USER", value = var.db_username },
        { name = "JOOMLA_DB_PREFIX", value = "joom_" },
        { name = "JOOMLA_SITE_NAME", value = var.site_name },
        { name = "JOOMLA_ADMIN_USER", value = "Administrador" },
        { name = "JOOMLA_ADMIN_USERNAME", value = var.admin_username },
        { name = "JOOMLA_ADMIN_EMAIL", value = var.admin_email },
        { name = "JOOMLA_CLI_COMMANDS", value = local.joomla_cli_commands },
      ]

      # Las contrasenas se inyectan desde Secrets Manager, nunca como texto plano
      secrets = [
        { name = "JOOMLA_DB_PASSWORD", valueFrom = "${var.db_password_secret_arn}:password::" },
        { name = "JOOMLA_ADMIN_PASSWORD", valueFrom = aws_secretsmanager_secret.admin_password.arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.joomla.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "joomla"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-joomla-task"
  }
}

# ---------- Application Load Balancer ----------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_security_group_id]

  drop_invalid_header_fields = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "joomla" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip" # obligatorio con Fargate (awsvpc)
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.joomla.arn
  }
}

# ---------- Servicio ECS ----------
resource "aws_ecs_service" "joomla" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.joomla.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # La instalacion de Joomla tarda: el ALB espera antes de evaluar la salud
  health_check_grace_period_seconds = 300
  enable_execute_command            = true

  # Joomla se instala en la BD al arrancar: nunca debe haber dos instaladores a la vez
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = true # sin NAT Gateway: la tarea sale por el Internet Gateway
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.joomla.arn
    container_name   = "joomla"
    container_port   = 80
  }

  # La tarea necesita el listener, el valor del secreto y los permisos IAM ya creados
  depends_on = [
    aws_lb_listener.http,
    aws_secretsmanager_secret_version.admin_password,
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy.read_secrets,
  ]

  tags = {
    Name = "${var.project_name}-service"
  }
}
