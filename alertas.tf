locals {
  nombre_alarma_errores = "${local.prefijo}-alarma-cola-errores"
  arn_alarma_errores    = "arn:aws:cloudwatch:${var.region_aws}:${data.aws_caller_identity.actual.account_id}:alarm:${local.nombre_alarma_errores}"
}

resource "aws_sns_topic" "errores" {
  name         = "${local.prefijo}-avisos-errores"
  display_name = "Alertas de procesamiento de imagenes"
}

resource "aws_sns_topic_policy" "errores" {
  arn = aws_sns_topic.errores.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicarAvisosDeLaAlarmaDeErrores"
      Effect    = "Allow"
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.errores.arn
      Condition = {
        ArnEquals    = { "aws:SourceArn" = local.arn_alarma_errores }
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.actual.account_id }
      }
    }]
  })
}

resource "aws_cloudwatch_metric_alarm" "errores" {
  alarm_name          = local.nombre_alarma_errores
  alarm_description   = "Avisa cuando existen mensajes visibles en la cola de errores del procesamiento de imagenes"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.errores.arn]

  dimensions = {
    QueueName = aws_sqs_queue.errores.name
  }

  depends_on = [aws_sns_topic_policy.errores]
}

output "alertas_errores" {
  description = "Alarma de la cola de errores y tema SNS para sus notificaciones."
  value = {
    nombre_alarma = aws_cloudwatch_metric_alarm.errores.alarm_name
    arn_alarma    = aws_cloudwatch_metric_alarm.errores.arn
    tema_sns_arn  = aws_sns_topic.errores.arn
  }
}
