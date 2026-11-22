# Estado remoto en S3 (bucket creado por bootstrap/). Los valores NO van aqui: se pasan en
# "terraform init" con -backend-config, tanto en local como en los pipelines.
terraform {
  backend "s3" {}
}
