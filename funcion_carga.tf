data "archive_file" "carga" {
  type        = "zip"
  source_dir  = "${path.module}/funciones/carga"
  output_path = "${path.module}/paquetes/carga.zip"
}

resource "aws_lambda_function" "carga" {
  function_name    = "${local.prefijo}-carga"
  description      = "Valida y guarda imagenes originales en el almacenamiento privado"
  role             = aws_iam_role.funciones["carga"].arn
  runtime          = "nodejs22.x"
  handler          = "indice.ejecutar"
  architectures    = ["x86_64"]
  memory_size      = 256
  timeout          = 30
  filename         = data.archive_file.carga.output_path
  source_code_hash = data.archive_file.carga.output_base64sha256

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.imagenes.id
      UPLOAD_PREFIX = local.prefijo_originales
    }
  }

  vpc_config {
    subnet_ids         = [for conexion in local.conexiones_privadas : aws_subnet.red[conexion.privada].id]
    security_group_ids = [aws_security_group.funciones["carga"].id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.registros_funciones,
    aws_iam_role_policy_attachment.red_funciones,
    aws_iam_role_policy.carga_imagenes,
    aws_cloudwatch_log_group.funciones,
    aws_vpc_endpoint.s3,
    aws_vpc_security_group_egress_rule.funciones_s3
  ]
}

output "funcion_carga" {
  description = "Nombre y ARN de la funcion que recibe las imagenes originales."
  value = {
    nombre = aws_lambda_function.carga.function_name
    arn    = aws_lambda_function.carga.arn
  }
}
