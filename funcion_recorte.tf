data "archive_file" "recorte" {
  type        = "zip"
  source_dir  = "${path.module}/funciones/recorte"
  output_path = "${path.module}/paquetes/recorte.zip"
}

resource "aws_lambda_function" "recorte" {
  function_name    = "${local.prefijo}-recorte"
  description      = "Genera recortes circulares de 40 por 40 pixeles desde la cola de imagenes"
  role             = aws_iam_role.funciones["recorte"].arn
  runtime          = "nodejs22.x"
  handler          = "indice.ejecutar"
  architectures    = ["x86_64"]
  memory_size      = 512
  timeout          = 60
  filename         = data.archive_file.recorte.output_path
  source_code_hash = data.archive_file.recorte.output_base64sha256

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.imagenes.id
      UPLOAD_PREFIX    = local.prefijo_originales
      PROCESSED_PREFIX = local.prefijo_procesadas
    }
  }

  vpc_config {
    subnet_ids         = [for conexion in local.conexiones_privadas : aws_subnet.red[conexion.privada].id]
    security_group_ids = [aws_security_group.funciones["recorte"].id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.registros_funciones,
    aws_iam_role_policy_attachment.red_funciones,
    aws_iam_role_policy.recorte_imagenes,
    aws_cloudwatch_log_group.funciones,
    aws_vpc_endpoint.s3,
    aws_vpc_security_group_egress_rule.funciones_s3
  ]
}

resource "aws_lambda_event_source_mapping" "imagenes" {
  event_source_arn        = aws_sqs_queue.imagenes.arn
  function_name           = aws_lambda_function.recorte.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
  enabled                 = true

  depends_on = [aws_iam_role_policy.recorte_imagenes]
}

output "funcion_recorte" {
  description = "Funcion de recorte y conexion automatica con la cola de imagenes."
  value = {
    nombre      = aws_lambda_function.recorte.function_name
    arn         = aws_lambda_function.recorte.arn
    conexion_id = aws_lambda_event_source_mapping.imagenes.uuid
  }
}
