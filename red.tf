data "aws_availability_zones" "disponibles" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }

  lifecycle {
    postcondition {
      condition     = length(self.names) >= 2
      error_message = "La arquitectura necesita al menos dos zonas de disponibilidad."
    }
  }
}

locals {
  prefijo = "${var.nombre_proyecto}-${var.entorno}"
  zonas   = slice(sort(data.aws_availability_zones.disponibles.names), 0, 2)

  subredes = {
    publica_a = {
      cidr = "10.0.1.0/24"
      zona = local.zonas[0]
    }
    publica_b = {
      cidr = "10.0.2.0/24"
      zona = local.zonas[1]
    }
    privada_a = {
      cidr = "10.0.11.0/24"
      zona = local.zonas[0]
    }
    privada_b = {
      cidr = "10.0.12.0/24"
      zona = local.zonas[1]
    }
  }
}

resource "aws_vpc" "principal" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.prefijo}-vpc"
  }

  lifecycle {
    precondition {
      condition     = terraform.workspace == var.entorno
      error_message = "El espacio de trabajo de Terraform debe coincidir con el entorno: dev, qa o prod."
    }
  }
}

resource "aws_subnet" "red" {
  for_each = local.subredes

  vpc_id                  = aws_vpc.principal.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.zona
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.prefijo}-${replace(each.key, "_", "-")}"
  }
}
