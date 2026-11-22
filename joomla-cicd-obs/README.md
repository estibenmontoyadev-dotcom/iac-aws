# Joomla con CI/CD y observabilidad en AWS (Actividad 6)

Joomla en **ECS Fargate** con **RDS MySQL**, **ElastiCache Valkey** y **EFS**, desplegado con **Terraform**
desde **GitHub Actions**, con **dashboard y alertas de CloudWatch** definidos como codigo.

| | |
|---|---|
| Nube / herramienta IaC | AWS / Terraform |
| Plataforma de CI/CD | GitHub Actions (autenticacion OIDC, sin claves guardadas) |
| Opcion A (CI/CD de la aplicacion) | `.github/workflows/joomla-app-cicd.yml` |
| Opcion B (CI/CD de la infraestructura) | `.github/workflows/joomla-infra-{plan,apply,destroy}.yml` |
| Observabilidad | `infra/modules/monitoring/` (dashboard, 15 alarmas, SNS, comprobacion de disponibilidad) |

## Estructura

```
joomla-cicd-obs/
  bootstrap/   se aplica UNA vez en local: bucket de estado, ECR, secreto, OIDC de GitHub y roles
  infra/       stack de Joomla, aplicado por el pipeline
    env/       prod.tfvars (valores no secretos)
    modules/   networking, database, cache, storage, app, monitoring
  app/         Dockerfile y codigo propio de Joomla (lo despliega el pipeline de la aplicacion)
  scripts/     smoke-test.sh
../.github/workflows/   los cuatro workflows (los workflows deben vivir en la raiz del repositorio)
```

## Flujos

| Quiero... | Hago... |
|---|---|
| Cambiar la infraestructura | PR que toque `infra/` -> `Joomla infra - plan` -> merge -> aprobar `Joomla infra - apply` |
| Desplegar un cambio de la aplicacion | PR que toque `app/` -> `Joomla app - CI/CD` (solo build) -> merge -> build, push a ECR, deploy, smoke test |
| Volver atras un despliegue | Automatico si falla el smoke test; manual: ver la guia (seccion de rollback) |
| Ver el estado del sitio | Dashboard `joomla-cicd-joomla` en CloudWatch (`terraform output dashboard_url`) |
| Eliminar todo | Workflow `Joomla infra - destroy` (escribir `destroy`) |

## Puesta en marcha

La guia paso a paso esta en `GUIA_Actividad6_Joomla_CICD_Observabilidad.md` (carpeta `E6/`).
Resumen: `bootstrap` en local -> variables y entorno `production` en GitHub -> PR de infraestructura -> PR de la aplicacion.

## Decisiones de diseno

- **EFS para el sitio.** La imagen oficial de Joomla instala el sitio solo si no encuentra `configuration.php`.
  Con contenedores efimeros eso ocurriria en cada despliegue y el instalador podria reescribir las tablas.
  Con el directorio web en EFS, un contenedor nuevo reutiliza el sitio ya instalado.
- **Codigo propio por imagen.** `app/custom/` se copia sobre el sitio al arrancar (`itm-start.sh`).
  El nucleo de Joomla se actualiza desde el propio Joomla (Sistema > Actualizar), porque vive en EFS.
- **Una sola tarea con `minimum_healthy_percent = 0`.** Joomla no debe tener dos instaladores a la vez;
  a cambio, cada despliegue tiene una breve interrupcion. El circuit breaker de ECS y el rollback del
  pipeline devuelven la revision anterior si la nueva no se estabiliza.
- **El servicio ignora `task_definition` en Terraform.** La imagen en ejecucion la decide el pipeline de la
  aplicacion. Un cambio de variables de entorno hecho por Terraform llega al servicio en el siguiente
  despliegue de la aplicacion (o con *Run workflow* manual).

## Limitaciones conocidas

- Sin HTTPS (el ALB atiende HTTP); para produccion, certificado de ACM y listener 443.
- Una sola tarea y sin NAT: las tareas usan IP publica y su Security Group solo admite trafico del ALB.
- El rol de Terraform tiene permisos por servicio (`ec2:*`, `rds:*`, ...); mejora: acotarlos a recursos del proyecto.
- La comprobacion de disponibilidad (Route 53) y su alarma solo funcionan en `us-east-1`.
- Las aprobaciones de entorno requieren repositorio publico o plan de GitHub que las incluya.
- El estado de `bootstrap/` es local: respaldar `bootstrap/terraform.tfstate` fuera de git.
