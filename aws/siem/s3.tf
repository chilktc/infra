resource "aws_s3_bucket" "log_archive" {
  bucket_prefix = "${var.project_name}-log-archive-"
  force_destroy = true # For demo purposes
  
  tags = {
    Name = "${var.project_name}-log-archive"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
