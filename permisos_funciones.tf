resource "aws_iam_role" "funciones" {
  for_each = aws_security_group.funciones

  name        = "${local.prefijo}-rol-${each.key}"
  description = "Rol de ejecucion de la funcion de ${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "registros_funciones" {
  for_each = aws_iam_role.funciones

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "red_funciones" {
  for_each = aws_iam_role.funciones

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "carga_imagenes" {
  name = "cargar-imagenes-originales"
  role = aws_iam_role.funciones["carga"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "CargarOriginales"
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.imagenes.arn}/${local.prefijo_originales}*"
    }]
  })
}

resource "aws_iam_role_policy" "recorte_imagenes" {
  name = "procesar-imagenes-de-la-cola"
  role = aws_iam_role.funciones["recorte"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LeerOriginales"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.imagenes.arn}/${local.prefijo_originales}*"
      },
      {
        Sid      = "GuardarRecortes"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.imagenes.arn}/${local.prefijo_procesadas}*"
      },
      {
        Sid    = "ConsumirMensajesDeImagenes"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.imagenes.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "funciones" {
  for_each = aws_iam_role.funciones

  name              = "/aws/lambda/${local.prefijo}-${each.key}"
  retention_in_days = 14
}
