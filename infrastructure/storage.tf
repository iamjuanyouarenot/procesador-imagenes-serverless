resource "aws_sqs_queue" "image_queue" {
  name                       = "image-processor-${var.environment}-image-queue"
  visibility_timeout_seconds = 360 # 6 veces el timeout del Lambda
  message_retention_seconds  = 86400 # 1 día
  receive_wait_time_seconds  = 20    # Long Polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_dlq.arn
    maxReceiveCount     = 3
  })
}

# 2. Dead-Letter Queue (DLQ)
resource "aws_sqs_queue" "image_dlq" {
  name                      = "image-processor-${var.environment}-image-dlq"
  message_retention_seconds = 1209600 # 14 días
}

# ==========================================
# AMAZON S3 (Almacenamiento de Fotos)
# ==========================================

# 3. Bucket S3 Principal
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "images" {
  bucket        = "image-processor-${var.environment}-images-${random_string.suffix.result}"
  force_destroy = true
}

# 4. Configuración de Notificación: S3 avisa a SQS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = aws_sqs_queue.image_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }

  depends_on = [aws_sqs_policy.allow_s3_logging]
}

# 5. Permiso para que S3 pueda escribir en la cola SQS
resource "aws_sqs_policy" "allow_s3_logging" {
  queue_url = aws_sqs_queue.image_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.image_queue.arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_s3_bucket.images.arn }
        }
      }
    ]
  })
}