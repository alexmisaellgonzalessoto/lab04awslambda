resource "aws_apigatewayv2_api" "carga" {
  name          = "${local.prefijo}-api-imagenes"
  description   = "Recepcion HTTPS de imagenes originales para su procesamiento"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}

resource "aws_cloudwatch_log_group" "api_carga" {
  name              = "/aws/apigateway/${local.prefijo}-api-imagenes"
  retention_in_days = 14
}

resource "aws_lambda_permission" "api_carga" {
  statement_id   = "PermitirCargaDesdeApi"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.carga.function_name
  principal      = "apigateway.amazonaws.com"
  source_arn     = "${aws_apigatewayv2_api.carga.execution_arn}/*/POST/upload"
  source_account = data.aws_caller_identity.actual.account_id
}

resource "aws_apigatewayv2_integration" "carga" {
  api_id                 = aws_apigatewayv2_api.carga.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.carga.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "carga" {
  api_id    = aws_apigatewayv2_api.carga.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.carga.id}"
}

resource "aws_apigatewayv2_stage" "carga" {
  api_id      = aws_apigatewayv2_api.carga.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 10000
    throttling_burst_limit = 5000
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_carga.arn
    format = jsonencode({
      solicitud_id      = "$context.requestId"
      fecha             = "$context.requestTime"
      metodo            = "$context.httpMethod"
      ruta              = "$context.routeKey"
      estado            = "$context.status"
      bytes_respuesta   = "$context.responseLength"
      error_integracion = "$context.integrationErrorMessage"
    })
  }

  depends_on = [aws_apigatewayv2_route.carga, aws_lambda_permission.api_carga]
}

output "url_carga" {
  description = "Direccion HTTPS para cargar imagenes mediante POST /upload."
  value       = "${aws_apigatewayv2_api.carga.api_endpoint}/upload"
}

output "api_imagenes" {
  description = "API de imagenes y grupo de registros de sus solicitudes."
  value = {
    id              = aws_apigatewayv2_api.carga.id
    grupo_registros = aws_cloudwatch_log_group.api_carga.name
  }
}
