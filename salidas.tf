output "vpc_id" {
  description = "Identificador de la VPC del entorno."
  value       = aws_vpc.principal.id
}

output "subredes" {
  description = "Identificadores, rangos de direcciones y zonas de las cuatro subredes."
  value = {
    for nombre, subred in aws_subnet.red : nombre => {
      id   = subred.id
      cidr = subred.cidr_block
      zona = subred.availability_zone
    }
  }
}
