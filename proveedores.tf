provider "aws" {
  region  = var.region_aws
  profile = var.perfil_aws

  default_tags {
    tags = {
      Project     = var.nombre_proyecto
      Environment = var.entorno
      ManagedBy   = "Terraform"
    }
  }
}
