# Bootstrap unico del CI/CD. Crea lo que los pipelines necesitan ANTES de poder ejecutarse:
# bucket de estado remoto, repositorio de imagenes (ECR), contrasena de Joomla en Secrets Manager,
# la identidad de GitHub Actions en AWS (OIDC, sin claves de larga duracion) y los roles de cada pipeline.
# Se aplica UNA vez, en local, con credenciales de administrador. Su estado queda en local.

data "aws_caller_identity" "current" {}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  state_bucket_name = "${var.project_name}-${local.account_id}-tfstate"
  repo_full_name    = "${var.github_owner}/${var.github_repo}"

  # GitHub puede emitir el claim "sub" con el formato clasico (repo:dueno/repo:...) o con los IDs numericos
  # (repo:dueno@ID/repo@ID:...). Los roles aceptan ambos para no depender de ese ajuste de GitHub.
  sub_prefixes = compact([
    "repo:${local.repo_full_name}",
    var.github_owner_id != "" && var.github_repo_id != "" ? "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}" : "",
  ])
  oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  # Roles que ECS usa y que el pipeline de la aplicacion debe poder "pasar" a la tarea (los crea infra/)
  ecs_execution_role_arn = "arn:aws:iam::${local.account_id}:role/${var.project_name}-ecs-execution-role"
  ecs_task_role_arn      = "arn:aws:iam::${local.account_id}:role/${var.project_name}-ecs-task-role"
  ecs_service_arn        = "arn:aws:ecs:${var.aws_region}:${local.account_id}:service/${var.project_name}-cluster/${var.project_name}-service"
}

# ---------------------------------------------------------------------------
# Estado remoto de Terraform (bucket S3 versionado, cifrado y privado)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket        = local.state_bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name = local.state_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "keep-last-20-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      newer_noncurrent_versions = 20
      noncurrent_days           = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

data "aws_iam_policy_document" "tfstate_tls" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_tls.json

  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

# ---------------------------------------------------------------------------
# Repositorio de imagenes (ECR) para el contenedor de Joomla
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "joomla" {
  name                 = var.project_name
  image_tag_mutability = "IMMUTABLE" # cada imagen se identifica con el SHA del commit y no se puede sobrescribir
  force_delete         = var.force_destroy

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "joomla" {
  repository = aws_ecr_repository.joomla.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Borrar imagenes sin etiqueta con mas de 14 dias"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Conservar solo las 20 imagenes mas recientes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# Contrasena del administrador de Joomla: la genera Terraform y la lee el pipeline
# ---------------------------------------------------------------------------
resource "random_password" "admin" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "tf_admin_password" {
  name                    = "${var.project_name}-tf-admin-password"
  description             = "Contrasena del administrador de Joomla; el pipeline la entrega a Terraform como TF_VAR_admin_password"
  recovery_window_in_days = 0 # laboratorio: permite recrear el secreto tras un destroy

  tags = {
    Name = "${var.project_name}-tf-admin-password"
  }
}

resource "aws_secretsmanager_secret_version" "tf_admin_password" {
  secret_id     = aws_secretsmanager_secret.tf_admin_password.id
  secret_string = random_password.admin.result
}

# ---------------------------------------------------------------------------
# Identidad de GitHub Actions en AWS (OIDC): los workflows piden credenciales temporales,
# no hay claves de acceso guardadas en GitHub
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1

  url = "https://token.actions.githubusercontent.com"
}

# ---------- Rol 1: plan (pull requests) - solo lectura ----------
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for p in local.sub_prefixes : "${p}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${var.project_name}-gha-plan"
  description        = "GitHub Actions: terraform plan en pull requests (solo lectura)"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }

  statement {
    sid       = "ListState"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid     = "ReadSecretValues"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${var.project_name}-*",
    ]
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "${var.project_name}-gha-plan"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

# ---------- Rol 2: infraestructura (apply / destroy) - solo el entorno con aprobacion ----------
data "aws_iam_policy_document" "tf_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for p in local.sub_prefixes : "${p}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "tf" {
  name               = "${var.project_name}-gha-terraform"
  description        = "GitHub Actions: terraform apply y destroy, solo desde el entorno ${var.github_environment}"
  assume_role_policy = data.aws_iam_policy_document.tf_trust.json
}

# Permisos por servicio (los que usa infra/). Mejora futura: acotar cada accion a recursos con el prefijo del proyecto.
data "aws_iam_policy_document" "tf" {
  statement {
    sid = "ServiciosDelStack"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "ecs:*",
      "rds:*",
      "elasticache:*",
      "elasticfilesystem:*",
      "secretsmanager:*",
      "cloudwatch:*",
      "logs:*",
      "sns:*",
      "events:*",
      "route53:*",
      "iam:*",
      "kms:Describe*",
      "kms:List*",
      "kms:Get*",
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EstadoRemoto"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }

  statement {
    sid       = "ListarEstado"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }
}

resource "aws_iam_role_policy" "tf" {
  name   = "${var.project_name}-gha-terraform"
  role   = aws_iam_role.tf.id
  policy = data.aws_iam_policy_document.tf.json
}

# ---------- Rol 3: aplicacion (build, push a ECR y deploy a ECS) - solo la rama principal ----------
data "aws_iam_policy_document" "app_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for p in local.sub_prefixes : "${p}:ref:refs/heads/${var.main_branch}"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.project_name}-gha-app"
  description        = "GitHub Actions: publica la imagen en ECR y despliega en ECS desde la rama ${var.main_branch}"
  assume_role_policy = data.aws_iam_policy_document.app_trust.json
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "LoginECR"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PublicarImagen"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.joomla.arn]
  }

  statement {
    sid       = "TareaECS"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "ServicioECS"
    actions   = ["ecs:DescribeServices", "ecs:UpdateService"]
    resources = [local.ecs_service_arn]
  }

  statement {
    sid       = "PasarRolesDeLaTarea"
    actions   = ["iam:PassRole"]
    resources = [local.ecs_execution_role_arn, local.ecs_task_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "DireccionDelBalanceador"
    actions   = ["elasticloadbalancing:DescribeLoadBalancers"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "${var.project_name}-gha-app"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}
