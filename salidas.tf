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

output "salidas_privadas" {
  description = "Puertas NAT, direcciones públicas y tablas de rutas por zona."
  value = {
    for zona, conexion in local.conexiones_privadas : zona => {
      nat_id         = aws_nat_gateway.salida[zona].id
      ip_publica     = aws_eip.nat[zona].public_ip
      tabla_rutas_id = aws_route_table.privada[zona].id
      subred_privada = aws_subnet.red[conexion.privada].id
    }
  }
}

output "almacenamiento_imagenes" {
  description = "Bucket privado y prefijos de las imágenes originales y procesadas."
  value = {
    bucket             = aws_s3_bucket.imagenes.id
    arn                = aws_s3_bucket.imagenes.arn
    prefijo_originales = local.prefijo_originales
    prefijo_procesadas = local.prefijo_procesadas
  }
}

output "colas_imagenes" {
  description = "Cola de procesamiento de imágenes y cola de errores del entorno."
  value = {
    procesamiento_url = aws_sqs_queue.imagenes.id
    procesamiento_arn = aws_sqs_queue.imagenes.arn
    errores_url       = aws_sqs_queue.errores.id
    errores_arn       = aws_sqs_queue.errores.arn
  }
}
