data "aws_caller_identity" "current" {}

locals {
  dashboard_name = "${var.project_name}-joomla"
  dashboard_url  = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${local.dashboard_name}"

  # Dimensiones de las metricas de cada servicio
  alb_dims   = { LoadBalancer = var.alb_arn_suffix }
  tg_dims    = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  ecs_dims   = { ClusterName = var.cluster_name, ServiceName = var.service_name }
  db_dims    = { DBInstanceIdentifier = var.db_instance_identifier }
  cache_dims = { CacheClusterId = var.cache_cluster_id }

  alarm_actions = [aws_sns_topic.alerts.arn]
  php_namespace = "${var.project_name}/Joomla"
}

# ---------------------------------------------------------------------------
# Canal de notificacion: SNS + correo
# ---------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name = "${var.project_name}-alerts"
  }
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid       = "AllowCloudWatchAlarms"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "AllowEventBridge"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# ---------------------------------------------------------------------------
# Comprobacion de disponibilidad (uptime check) sobre el balanceador
# ---------------------------------------------------------------------------
resource "aws_route53_health_check" "site" {
  type              = "HTTP"
  fqdn              = var.alb_dns_name
  port              = 80
  resource_path     = var.uptime_path
  request_interval  = 30
  failure_threshold = 3

  tags = {
    Name = "${var.project_name}-uptime"
  }
}

# ---------------------------------------------------------------------------
# Metrica basada en logs: errores fatales de PHP
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "php_fatal" {
  name           = "${var.project_name}-php-fatal-errors"
  log_group_name = var.log_group_name
  pattern        = "\"PHP Fatal error\""

  metric_transformation {
    name          = "PhpFatalErrors"
    namespace     = local.php_namespace
    value         = "1"
    default_value = "0"
  }
}

# ---------------------------------------------------------------------------
# Alertas - BACKEND
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "uptime" {
  alarm_name        = "${var.project_name} [Backend] Sitio caido (uptime check)"
  alarm_description = "CRITICA. Route 53 no recibe respuesta 2xx/3xx del sitio. Revisar: 1) servicio ECS (tareas en ejecucion), 2) logs del contenedor, 3) alertas de base de datos, 4) si coincide con un despliegue, hacer rollback. Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  dimensions          = { HealthCheckId = aws_route53_health_check.site.id }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "backend", Component = "alb", Severity = "critical" }

  lifecycle {
    precondition {
      condition     = var.aws_region == "us-east-1"
      error_message = "Route 53 solo publica HealthCheckStatus en us-east-1; despliega en esa region o elimina esta alarma."
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_ratio" {
  alarm_name        = "${var.project_name} [Backend] Porcentaje de 5xx alto"
  alarm_description = "CRITICA. Mas del ${var.alb_5xx_percent_threshold}% de las respuestas del backend son 5xx durante 5 min (con al menos 10 peticiones). 502/503: contenedor saturado o reiniciando. 500: revisar logs por PHP Fatal error y el ultimo despliegue. Dashboard: ${local.dashboard_url}"

  evaluation_periods  = 1
  threshold           = var.alb_5xx_percent_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "ratio"
    expression  = "IF(requests >= 10, 100 * errors / requests, 0)"
    label       = "Porcentaje de 5xx"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = local.alb_dims
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = local.alb_dims
      period      = 300
      stat        = "Sum"
    }
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "backend", Component = "alb", Severity = "critical" }
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name        = "${var.project_name} [Backend] Latencia p95 alta"
  alarm_description = "ADVERTENCIA. El percentil 95 del tiempo de respuesta supera ${var.latency_p95_seconds_threshold} s durante 10 min. Causas habituales: Valkey desconectado, consultas lentas en RDS, CPU del contenedor al limite. Revisar las secciones ECS y Bases de datos del dashboard: ${local.dashboard_url}"

  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = local.alb_dims
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.latency_p95_seconds_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "backend", Component = "alb", Severity = "warning" }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name        = "${var.project_name} [Backend] Contenedor no saludable en el balanceador"
  alarm_description = "CRITICA. El grupo de destino tiene al menos un contenedor que no pasa el health check durante 3 min. Revisar los logs del contenedor y el estado de la tarea en ECS. Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = local.tg_dims
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "backend", Component = "alb", Severity = "critical" }
}

resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks" {
  alarm_name        = "${var.project_name} [Backend] Sin tareas en ejecucion"
  alarm_description = "CRITICA. El servicio ECS lleva 5 min sin ninguna tarea en ejecucion. Revisar los eventos del servicio y las tareas detenidas (motivo de parada). Si coincide con un despliegue, volver a la revision anterior. Dashboard: ${local.dashboard_url}"

  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  dimensions          = local.ecs_dims
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "backend", Component = "ecs", Severity = "critical" }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name        = "${var.project_name} [Backend] CPU del contenedor alta"
  alarm_description = "ADVERTENCIA. CPU promedio del servicio por encima de ${var.ecs_cpu_threshold}% durante 10 min. Considerar subir task_cpu o desired_count (con EFS compartido). Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = local.ecs_dims
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.ecs_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "backend", Component = "ecs", Severity = "warning" }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name        = "${var.project_name} [Backend] Memoria del contenedor alta"
  alarm_description = "ADVERTENCIA. Memoria promedio del servicio por encima de ${var.ecs_memory_threshold}% durante 10 min. Riesgo de que ECS reinicie la tarea por falta de memoria. Considerar subir task_memory. Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions          = local.ecs_dims
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.ecs_memory_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "backend", Component = "ecs", Severity = "warning" }
}

resource "aws_cloudwatch_metric_alarm" "php_fatal" {
  alarm_name        = "${var.project_name} [Backend] Errores fatales de PHP"
  alarm_description = "ADVERTENCIA. Mas de ${var.php_fatal_errors_threshold} lineas 'PHP Fatal error' en 5 min. Suele ser un error de codigo del ultimo despliegue o una extension de Joomla defectuosa. Ver los logs con la consulta del dashboard y, si coincide con un despliegue, hacer rollback. Dashboard: ${local.dashboard_url}"

  namespace           = local.php_namespace
  metric_name         = aws_cloudwatch_log_metric_filter.php_fatal.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.php_fatal_errors_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "backend", Component = "app", Severity = "warning" }
}

# ---------------------------------------------------------------------------
# Alertas - BASES DE DATOS
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  alarm_name        = "${var.project_name} [DB] CPU de RDS alta"
  alarm_description = "ADVERTENCIA. CPU de RDS por encima de ${var.db_cpu_threshold}% durante 10 min. Revisar consultas lentas y la cache de Joomla (Valkey). Considerar una clase de instancia mayor. Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = local.db_dims
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.db_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "database", Component = "rds", Severity = "warning" }
}

resource "aws_cloudwatch_metric_alarm" "db_free_storage" {
  alarm_name        = "${var.project_name} [DB] Poco espacio libre en RDS"
  alarm_description = "CRITICA. Quedan menos de ${floor(var.db_free_storage_bytes_threshold / 1073741824)} GiB libres en RDS. Revisar tablas grandes (sesiones, logs de acciones) y ampliar allocated_storage antes de que se llene. Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = local.db_dims
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.db_free_storage_bytes_threshold
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "database", Component = "rds", Severity = "critical" }
}

resource "aws_cloudwatch_metric_alarm" "db_freeable_memory" {
  alarm_name        = "${var.project_name} [DB] Poca memoria libre en RDS"
  alarm_description = "ADVERTENCIA. La memoria liberable de RDS esta por debajo de ${floor(var.db_freeable_memory_bytes_threshold / 1048576)} MiB durante 10 min. Revisar conexiones abiertas y considerar una clase de instancia con mas memoria. Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  dimensions          = local.db_dims
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.db_freeable_memory_bytes_threshold
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "database", Component = "rds", Severity = "warning" }
}

resource "aws_cloudwatch_metric_alarm" "db_connections" {
  alarm_name        = "${var.project_name} [DB] Conexiones a RDS cerca del limite"
  alarm_description = "CRITICA. Mas de ${var.db_connections_threshold} conexiones abiertas a RDS durante 5 min (db.t4g.micro admite unas 85). Revisar si hay mas tareas de las previstas o conexiones colgadas. Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = local.db_dims
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.db_connections_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "database", Component = "rds", Severity = "critical" }
}

resource "aws_cloudwatch_metric_alarm" "cache_cpu" {
  alarm_name        = "${var.project_name} [DB] CPU de Valkey alta"
  alarm_description = "ADVERTENCIA. La CPU del motor de Valkey supera ${var.cache_cpu_threshold}% durante 10 min. Revisar el volumen de sesiones y la cache de Joomla. Considerar un tipo de nodo mayor. Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/ElastiCache"
  metric_name         = "EngineCPUUtilization"
  dimensions          = local.cache_dims
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.cache_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "database", Component = "valkey", Severity = "warning" }
}

resource "aws_cloudwatch_metric_alarm" "cache_memory" {
  alarm_name        = "${var.project_name} [DB] Memoria de Valkey alta"
  alarm_description = "ADVERTENCIA. Valkey usa mas de ${var.cache_memory_threshold}% de su memoria durante 10 min. Habra expulsion de claves y mas consultas a RDS. Subir cache_node_type o limpiar la cache de Joomla. Dashboard: ${local.dashboard_url}"

  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  dimensions          = local.cache_dims
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.cache_memory_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "database", Component = "valkey", Severity = "warning" }
}

resource "aws_cloudwatch_metric_alarm" "cache_hit_ratio" {
  alarm_name        = "${var.project_name} [DB] Aciertos de Valkey bajos"
  alarm_description = "ADVERTENCIA. Menos de ${var.cache_hit_ratio_threshold}% de las lecturas a Valkey acierta durante 30 min (con al menos 100 consultas por periodo). Comprobar en Joomla que el manejador de cache sea Redis y que Valkey no este expulsando claves. Dashboard: ${local.dashboard_url}"

  evaluation_periods  = 6
  threshold           = var.cache_hit_ratio_threshold
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "ratio"
    expression  = "IF((hits + misses) >= 100, 100 * hits / (hits + misses), 100)"
    label       = "Porcentaje de aciertos"
    return_data = true
  }

  metric_query {
    id = "hits"
    metric {
      namespace   = "AWS/ElastiCache"
      metric_name = "CacheHits"
      dimensions  = local.cache_dims
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id = "misses"
    metric {
      namespace   = "AWS/ElastiCache"
      metric_name = "CacheMisses"
      dimensions  = local.cache_dims
      period      = 300
      stat        = "Sum"
    }
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = { Category = "database", Component = "valkey", Severity = "warning" }
}

# ---------------------------------------------------------------------------
# Alerta de CI/CD: despliegue de ECS fallido (EventBridge -> SNS)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "deploy_failed" {
  name        = "${var.project_name}-ecs-deploy-failed"
  description = "Avisa cuando un despliegue del servicio ECS falla (incluye el rollback automatico)"

  event_pattern = jsonencode({
    source        = ["aws.ecs"]
    "detail-type" = ["ECS Deployment State Change"]
    resources     = [var.service_arn]
    detail        = { eventType = ["ERROR"] }
  })

  tags = { Category = "cicd", Component = "ecs", Severity = "warning" }
}

resource "aws_cloudwatch_event_target" "deploy_failed" {
  rule      = aws_cloudwatch_event_rule.deploy_failed.name
  target_id = "sns"
  arn       = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      event  = "$.detail.eventName"
      reason = "$.detail.reason"
      time   = "$.time"
    }
    input_template = "\"[CI/CD][ECS] Despliegue fallido: <event>. Motivo: <reason>. Hora: <time>. Revisar la ejecucion del workflow en GitHub Actions y la pestana Eventos del servicio ECS.\""
  }

  depends_on = [aws_sns_topic_policy.alerts]
}
