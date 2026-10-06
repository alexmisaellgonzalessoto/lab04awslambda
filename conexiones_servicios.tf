resource "aws_security_group" "funciones" {
  for_each = toset(["carga", "recorte"])

  name        = "${local.prefijo}-seguridad-${each.key}"
  description = "Acceso privado de la funcion de ${each.key} a S3 y SQS"
  vpc_id      = aws_vpc.principal.id

  tags = {
    Name = "${local.prefijo}-seguridad-${each.key}"
  }
}

resource "aws_security_group" "conexion_sqs" {
  name        = "${local.prefijo}-seguridad-conexion-sqs"
  description = "Recepcion HTTPS desde las funciones del proyecto"
  vpc_id      = aws_vpc.principal.id

  tags = {
    Name = "${local.prefijo}-seguridad-conexion-sqs"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.principal.id
  service_name      = "com.amazonaws.${var.region_aws}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for tabla in aws_route_table.privada : tabla.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AccederImagenesDelProyecto"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject"]
      Resource  = ["${aws_s3_bucket.imagenes.arn}/*"]
    }]
  })

  tags = {
    Name = "${local.prefijo}-conexion-s3"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.principal.id
  service_name        = "com.amazonaws.${var.region_aws}.sqs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for conexion in local.conexiones_privadas : aws_subnet.red[conexion.privada].id]
  security_group_ids  = [aws_security_group.conexion_sqs.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ConsumirColaDelProyecto"
      Effect    = "Allow"
      Principal = "*"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ]
      Resource = aws_sqs_queue.imagenes.arn
    }]
  })

  tags = {
    Name = "${local.prefijo}-conexion-sqs"
  }
}

resource "aws_vpc_security_group_egress_rule" "funciones_s3" {
  for_each = aws_security_group.funciones

  security_group_id = each.value.id
  description       = "Salida HTTPS hacia Amazon S3"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "funciones_sqs" {
  for_each = aws_security_group.funciones

  security_group_id            = each.value.id
  description                  = "Salida HTTPS hacia la conexion privada de SQS"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.conexion_sqs.id
}

resource "aws_vpc_security_group_ingress_rule" "sqs_funciones" {
  for_each = aws_security_group.funciones

  security_group_id            = aws_security_group.conexion_sqs.id
  description                  = "Entrada HTTPS desde la funcion de ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = each.value.id
}
