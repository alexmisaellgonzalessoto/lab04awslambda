resource "aws_sqs_queue_policy" "cargas_s3" {
  queue_url = aws_sqs_queue.imagenes.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PermitirCargasDelBucket"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.imagenes.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_s3_bucket.imagenes.arn
        }
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.actual.account_id
        }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "cargas" {
  bucket = aws_s3_bucket.imagenes.id

  queue {
    id            = "procesar-imagenes-originales"
    queue_arn     = aws_sqs_queue.imagenes.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = local.prefijo_originales
  }

  depends_on = [aws_sqs_queue_policy.cargas_s3]
}
