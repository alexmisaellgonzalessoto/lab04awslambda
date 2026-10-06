data "aws_caller_identity" "actual" {}

output "cuenta_aws" {
  description = "Cuenta de AWS utilizada por el perfil configurado."
  value       = data.aws_caller_identity.actual.account_id
}

output "identidad_aws" {
  description = "Identidad utilizada por Terraform para acceder a AWS."
  value       = data.aws_caller_identity.actual.arn
}
