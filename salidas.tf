output "vpc_id" {
  description = "Identificador de la VPC del entorno."
  value       = aws_vpc.principal.id
}

output "puerta_internet_id" {
  description = "Identificador de la puerta de enlace de Internet del entorno."
  value       = aws_internet_gateway.principal.id
}

output "tabla_rutas_publicas_id" {
  description = "Tabla de rutas compartida por las dos subredes públicas."
  value       = aws_route_table.publica.id
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
