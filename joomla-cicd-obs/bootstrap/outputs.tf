output "state_bucket" {
  description = "Bucket S3 del estado remoto de infra/"
  value       = aws_s3_bucket.tfstate.bucket
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR"
  value       = aws_ecr_repository.joomla.repository_url
}

output "admin_password_secret" {
  description = "Secreto con la contrasena del administrador de Joomla (se lee con: aws secretsmanager get-secret-value)"
  value       = aws_secretsmanager_secret.tf_admin_password.name
}

output "github_variables" {
  description = "Variables que deben crearse en GitHub (Settings > Secrets and variables > Actions > Variables)"
  value = {
    AWS_REGION             = var.aws_region
    PROJECT_NAME           = var.project_name
    TF_STATE_BUCKET        = aws_s3_bucket.tfstate.bucket
    ECR_REPOSITORY         = aws_ecr_repository.joomla.name
    ADMIN_PASSWORD_SECRET  = aws_secretsmanager_secret.tf_admin_password.name
    AWS_ROLE_PLAN_ARN      = aws_iam_role.plan.arn
    AWS_ROLE_TERRAFORM_ARN = aws_iam_role.tf.arn
    AWS_ROLE_APP_ARN       = aws_iam_role.app.arn
  }
}
