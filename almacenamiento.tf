locals {
  prefijo_originales = "uploads/"
  prefijo_procesadas = "processed/"
}

resource "aws_s3_bucket" "imagenes" {
  bucket        = "${local.prefijo}-imagenes-${data.aws_caller_identity.actual.account_id}-${var.region_aws}"
  force_destroy = false

  tags = {
    Name = "${local.prefijo}-imagenes"
  }
}

resource "aws_s3_bucket_public_access_block" "imagenes" {
  bucket = aws_s3_bucket.imagenes.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "imagenes" {
  bucket = aws_s3_bucket.imagenes.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "imagenes" {
  bucket = aws_s3_bucket.imagenes.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "imagenes" {
  bucket = aws_s3_bucket.imagenes.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "imagenes" {
  bucket = aws_s3_bucket.imagenes.id

  rule {
    id     = "expirar-originales"
    status = "Enabled"

    filter {
      prefix = local.prefijo_originales
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "expirar-procesadas"
    status = "Enabled"

    filter {
      prefix = local.prefijo_procesadas
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.imagenes]
}
