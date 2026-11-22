locals {
  all_alarm_arns = [
    aws_cloudwatch_metric_alarm.uptime.arn,
    aws_cloudwatch_metric_alarm.alb_5xx_ratio.arn,
    aws_cloudwatch_metric_alarm.alb_latency.arn,
    aws_cloudwatch_metric_alarm.unhealthy_hosts.arn,
    aws_cloudwatch_metric_alarm.ecs_running_tasks.arn,
    aws_cloudwatch_metric_alarm.ecs_cpu.arn,
    aws_cloudwatch_metric_alarm.ecs_memory.arn,
    aws_cloudwatch_metric_alarm.php_fatal.arn,
    aws_cloudwatch_metric_alarm.db_cpu.arn,
    aws_cloudwatch_metric_alarm.db_free_storage.arn,
    aws_cloudwatch_metric_alarm.db_freeable_memory.arn,
    aws_cloudwatch_metric_alarm.db_connections.arn,
    aws_cloudwatch_metric_alarm.cache_cpu.arn,
    aws_cloudwatch_metric_alarm.cache_memory.arn,
    aws_cloudwatch_metric_alarm.cache_hit_ratio.arn,
  ]

  # Atajos para escribir las metricas del dashboard: [espacio, nombre, dimension, valor, ...]
  lb  = var.alb_arn_suffix
  tg  = var.target_group_arn_suffix
  clu = var.cluster_name
  svc = var.service_name
  db  = var.db_instance_identifier
  ch  = var.cache_cluster_id
  rg  = var.aws_region

  log_query = "SOURCE '${var.log_group_name}' | fields @timestamp, @message | filter @message like /(?i)(error|fatal|exception)/ | sort @timestamp desc | limit 50"

  widgets = [
    # ---------------- Resumen ----------------
    {
      type = "text", x = 0, y = 0, width = 24, height = 2
      properties = {
        markdown = "# ${var.project_name} - Joomla en ECS Fargate\nTriada de observabilidad: **metricas** (graficos), **logs** (seccion de logs) y **alertas** (estado de las alarmas, aviso por correo con SNS). Las lineas rojas de los graficos son los mismos umbrales de las alarmas."
      }
    },
    {
      type = "alarm", x = 0, y = 2, width = 24, height = 4
      properties = {
        title  = "Estado de las alarmas"
        alarms = local.all_alarm_arns
      }
    },
    {
      type = "metric", x = 0, y = 6, width = 4, height = 4
      properties = {
        title   = "Peticiones (5 min)", view = "singleValue", region = local.rg, period = 300, stat = "Sum"
        metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.lb]]
      }
    },
    {
      type = "metric", x = 4, y = 6, width = 4, height = 4
      properties = {
        title   = "Latencia p95 (s)", view = "singleValue", region = local.rg, period = 300, stat = "p95"
        metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.lb]]
      }
    },
    {
      type = "metric", x = 8, y = 6, width = 4, height = 4
      properties = {
        title   = "Tareas en ejecucion", view = "singleValue", region = local.rg, period = 60, stat = "Maximum"
        metrics = [["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", local.clu, "ServiceName", local.svc]]
      }
    },
    {
      type = "metric", x = 12, y = 6, width = 4, height = 4
      properties = {
        title   = "CPU de RDS (%)", view = "singleValue", region = local.rg, period = 300, stat = "Average"
        metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", local.db]]
      }
    },
    {
      type = "metric", x = 16, y = 6, width = 4, height = 4
      properties = {
        title   = "Conexiones a RDS", view = "singleValue", region = local.rg, period = 300, stat = "Maximum"
        metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", local.db]]
      }
    },
    {
      type = "metric", x = 20, y = 6, width = 4, height = 4
      properties = {
        title   = "Memoria de Valkey (%)", view = "singleValue", region = local.rg, period = 300, stat = "Average"
        metrics = [["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", local.ch]]
      }
    },

    # ---------------- Backend: balanceador ----------------
    {
      type       = "text", x = 0, y = 10, width = 24, height = 1
      properties = { markdown = "## Backend - Balanceador de carga (ALB)" }
    },
    {
      type = "metric", x = 0, y = 11, width = 8, height = 6
      properties = {
        title = "Respuestas por clase HTTP", view = "timeSeries", stacked = true, region = local.rg, period = 300, stat = "Sum"
        metrics = [
          ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", local.lb, { label = "2xx" }],
          ["AWS/ApplicationELB", "HTTPCode_Target_3XX_Count", "LoadBalancer", local.lb, { label = "3xx" }],
          ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", local.lb, { label = "4xx" }],
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.lb, { label = "5xx" }],
        ]
      }
    },
    {
      type = "metric", x = 8, y = 11, width = 8, height = 6
      properties = {
        title = "Porcentaje de respuestas 5xx", view = "timeSeries", region = local.rg, period = 300, stat = "Sum"
        metrics = [
          [{ expression = "IF(requests >= 10, 100 * errors / requests, 0)", label = "% 5xx", id = "ratio" }],
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.lb, { id = "errors", visible = false }],
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.lb, { id = "requests", visible = false }],
        ]
        annotations = { horizontal = [{ label = "Umbral de la alarma", value = var.alb_5xx_percent_threshold, color = "#d13212" }] }
        yAxis       = { left = { min = 0 } }
      }
    },
    {
      type = "metric", x = 16, y = 11, width = 8, height = 6
      properties = {
        title = "Latencia del backend (s)", view = "timeSeries", region = local.rg, period = 300
        metrics = [
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.lb, { stat = "p50", label = "p50" }],
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.lb, { stat = "p95", label = "p95" }],
        ]
        annotations = { horizontal = [{ label = "Umbral p95", value = var.latency_p95_seconds_threshold, color = "#d13212" }] }
        yAxis       = { left = { min = 0 } }
      }
    },

    # ---------------- Backend: ECS ----------------
    {
      type       = "text", x = 0, y = 17, width = 24, height = 1
      properties = { markdown = "## Backend - Contenedor Joomla (ECS Fargate)" }
    },
    {
      type = "metric", x = 0, y = 18, width = 8, height = 6
      properties = {
        title = "CPU y memoria del servicio (%)", view = "timeSeries", region = local.rg, period = 300, stat = "Average"
        metrics = [
          ["AWS/ECS", "CPUUtilization", "ClusterName", local.clu, "ServiceName", local.svc, { label = "CPU" }],
          ["AWS/ECS", "MemoryUtilization", "ClusterName", local.clu, "ServiceName", local.svc, { label = "Memoria" }],
        ]
        annotations = { horizontal = [
          { label = "CPU", value = var.ecs_cpu_threshold, color = "#d13212" },
          { label = "Memoria", value = var.ecs_memory_threshold, color = "#ff9900" },
        ] }
        yAxis = { left = { min = 0, max = 100 } }
      }
    },
    {
      type = "metric", x = 8, y = 18, width = 8, height = 6
      properties = {
        title = "Tareas deseadas y en ejecucion", view = "timeSeries", region = local.rg, period = 60, stat = "Maximum"
        metrics = [
          ["ECS/ContainerInsights", "DesiredTaskCount", "ClusterName", local.clu, "ServiceName", local.svc, { label = "Deseadas" }],
          ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", local.clu, "ServiceName", local.svc, { label = "En ejecucion" }],
        ]
        yAxis = { left = { min = 0 } }
      }
    },
    {
      type = "metric", x = 16, y = 18, width = 8, height = 6
      properties = {
        title = "Contenedores saludables en el balanceador", view = "timeSeries", region = local.rg, period = 60, stat = "Maximum"
        metrics = [
          ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", local.lb, "TargetGroup", local.tg, { label = "Saludables" }],
          ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", local.lb, "TargetGroup", local.tg, { label = "No saludables" }],
        ]
        yAxis = { left = { min = 0 } }
      }
    },

    # ---------------- Logs ----------------
    {
      type       = "text", x = 0, y = 24, width = 24, height = 1
      properties = { markdown = "## Logs de la aplicacion (CloudWatch Logs)" }
    },
    {
      type = "log", x = 0, y = 25, width = 16, height = 7
      properties = {
        title  = "Ultimos errores del contenedor (ERROR, Fatal, Exception)"
        region = local.rg
        view   = "table"
        query  = local.log_query
      }
    },
    {
      type = "metric", x = 16, y = 25, width = 8, height = 7
      properties = {
        title       = "Errores fatales de PHP (metrica creada desde los logs)", view = "timeSeries", region = local.rg, period = 300, stat = "Sum"
        metrics     = [[local.php_namespace, "PhpFatalErrors"]]
        annotations = { horizontal = [{ label = "Umbral", value = var.php_fatal_errors_threshold, color = "#d13212" }] }
        yAxis       = { left = { min = 0 } }
      }
    },

    # ---------------- RDS ----------------
    {
      type       = "text", x = 0, y = 32, width = 24, height = 1
      properties = { markdown = "## Base de datos relacional - Amazon RDS MySQL" }
    },
    {
      type = "metric", x = 0, y = 33, width = 8, height = 6
      properties = {
        title       = "CPU de RDS (%)", view = "timeSeries", region = local.rg, period = 300, stat = "Average"
        metrics     = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", local.db]]
        annotations = { horizontal = [{ label = "Umbral", value = var.db_cpu_threshold, color = "#d13212" }] }
        yAxis       = { left = { min = 0, max = 100 } }
      }
    },
    {
      type = "metric", x = 8, y = 33, width = 8, height = 6
      properties = {
        title       = "Conexiones abiertas", view = "timeSeries", region = local.rg, period = 300, stat = "Maximum"
        metrics     = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", local.db]]
        annotations = { horizontal = [{ label = "Umbral", value = var.db_connections_threshold, color = "#d13212" }] }
        yAxis       = { left = { min = 0 } }
      }
    },
    {
      type = "metric", x = 16, y = 33, width = 8, height = 6
      properties = {
        title       = "Espacio libre (bytes)", view = "timeSeries", region = local.rg, period = 300, stat = "Minimum"
        metrics     = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", local.db]]
        annotations = { horizontal = [{ label = "Umbral", value = var.db_free_storage_bytes_threshold, color = "#d13212" }] }
      }
    },
    {
      type = "metric", x = 0, y = 39, width = 8, height = 6
      properties = {
        title       = "Memoria liberable (bytes)", view = "timeSeries", region = local.rg, period = 300, stat = "Minimum"
        metrics     = [["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", local.db]]
        annotations = { horizontal = [{ label = "Umbral", value = var.db_freeable_memory_bytes_threshold, color = "#d13212" }] }
      }
    },
    {
      type = "metric", x = 8, y = 39, width = 8, height = 6
      properties = {
        title = "IOPS de lectura y escritura", view = "timeSeries", region = local.rg, period = 300, stat = "Average"
        metrics = [
          ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", local.db, { label = "Lectura" }],
          ["AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", local.db, { label = "Escritura" }],
        ]
      }
    },
    {
      type = "metric", x = 16, y = 39, width = 8, height = 6
      properties = {
        title = "Latencia de disco (s)", view = "timeSeries", region = local.rg, period = 300, stat = "Average"
        metrics = [
          ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", local.db, { label = "Lectura" }],
          ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", local.db, { label = "Escritura" }],
        ]
      }
    },

    # ---------------- Valkey ----------------
    {
      type       = "text", x = 0, y = 45, width = 24, height = 1
      properties = { markdown = "## Base de datos en memoria - Amazon ElastiCache (Valkey)" }
    },
    {
      type = "metric", x = 0, y = 46, width = 8, height = 6
      properties = {
        title       = "CPU del motor (%)", view = "timeSeries", region = local.rg, period = 300, stat = "Average"
        metrics     = [["AWS/ElastiCache", "EngineCPUUtilization", "CacheClusterId", local.ch]]
        annotations = { horizontal = [{ label = "Umbral", value = var.cache_cpu_threshold, color = "#d13212" }] }
        yAxis       = { left = { min = 0, max = 100 } }
      }
    },
    {
      type = "metric", x = 8, y = 46, width = 8, height = 6
      properties = {
        title       = "Memoria usada (%)", view = "timeSeries", region = local.rg, period = 300, stat = "Average"
        metrics     = [["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", local.ch]]
        annotations = { horizontal = [{ label = "Umbral", value = var.cache_memory_threshold, color = "#d13212" }] }
        yAxis       = { left = { min = 0, max = 100 } }
      }
    },
    {
      type = "metric", x = 16, y = 46, width = 8, height = 6
      properties = {
        title = "Porcentaje de aciertos de la cache", view = "timeSeries", region = local.rg, period = 300, stat = "Sum"
        metrics = [
          [{ expression = "IF((hits + misses) >= 100, 100 * hits / (hits + misses), 100)", label = "% aciertos", id = "ratio" }],
          ["AWS/ElastiCache", "CacheHits", "CacheClusterId", local.ch, { id = "hits", visible = false }],
          ["AWS/ElastiCache", "CacheMisses", "CacheClusterId", local.ch, { id = "misses", visible = false }],
        ]
        annotations = { horizontal = [{ label = "Umbral", value = var.cache_hit_ratio_threshold, color = "#d13212" }] }
        yAxis       = { left = { min = 0, max = 100 } }
      }
    },
    {
      type = "metric", x = 0, y = 52, width = 12, height = 6
      properties = {
        title   = "Clientes conectados (contenedor Joomla)", view = "timeSeries", region = local.rg, period = 300, stat = "Maximum"
        metrics = [["AWS/ElastiCache", "CurrConnections", "CacheClusterId", local.ch]]
        yAxis   = { left = { min = 0 } }
      }
    },
    {
      type = "metric", x = 12, y = 52, width = 12, height = 6
      properties = {
        title = "Claves guardadas y expulsadas", view = "timeSeries", region = local.rg, period = 300, stat = "Maximum"
        metrics = [
          ["AWS/ElastiCache", "CurrItems", "CacheClusterId", local.ch, { label = "Claves" }],
          ["AWS/ElastiCache", "Evictions", "CacheClusterId", local.ch, { label = "Expulsadas", stat = "Sum" }],
        ]
        yAxis = { left = { min = 0 } }
      }
    },
  ]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.dashboard_name
  dashboard_body = jsonencode({ widgets = local.widgets })
}
