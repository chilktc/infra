resource "aws_opensearch_domain" "siem" {
  domain_name    = "${var.project_name}-domain"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 1
    zone_awareness_enabled = false
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp3"
  }

  vpc_options {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.opensearch.id]
  }

  # Allow access via IAM (specifically ECS Task Role)
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = "es:*"
        Resource = "arn:aws:es:${var.aws_region}:*:domain/${var.project_name}-domain/*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-opensearch"
  }
}
