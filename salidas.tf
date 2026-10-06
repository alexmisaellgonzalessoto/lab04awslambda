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

output "conexiones_servicios" {
  description = "Conexiones privadas a S3 y SQS y grupos de seguridad de las funciones."
  value = {
    s3_id               = aws_vpc_endpoint.s3.id
    s3_lista_prefijos   = aws_vpc_endpoint.s3.prefix_list_id
    sqs_id              = aws_vpc_endpoint.sqs.id
    sqs_interfaces      = aws_vpc_endpoint.sqs.network_interface_ids
    seguridad_sqs       = aws_security_group.conexion_sqs.id
    seguridad_funciones = { for nombre, grupo in aws_security_group.funciones : nombre => grupo.id }
  }
}

output "ejecucion_funciones" {
  description = "Roles de ejecución y grupos de registros de las funciones Lambda."
  value = {
    for nombre, rol in aws_iam_role.funciones : nombre => {
      rol_arn         = rol.arn
      grupo_registros = aws_cloudwatch_log_group.funciones[nombre].name
    }
  }
}
