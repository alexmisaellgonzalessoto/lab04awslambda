resource "aws_sqs_queue" "errores" {
  name                      = "${local.prefijo}-cola-errores"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "imagenes" {
  name                       = "${local.prefijo}-cola-imagenes"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 360
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.errores.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "errores" {
  queue_url = aws_sqs_queue.errores.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.imagenes.arn]
  })
}
