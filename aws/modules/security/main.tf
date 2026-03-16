locals {
  name_prefix = "${var.project}-${var.env}"
}

variable "project" {}
variable "env" {}
variable "vpc_id" {}
variable "tags" {
  type    = map(string)
  default = {}
}

###############################
# ALB Security Group
###############################
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

###############################
# App Security Group
###############################
resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Allow traffic from ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 5601
    to_port         = 5601
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    self        = true
    description = "Allow internal Node Exporter scraping"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-app-sg"
  })
}

###############################
# IAM Role for EC2 (SSM)
###############################
resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "s3_logs_backup" {
  name = "${local.name_prefix}-s3-logs-backup"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::t7-mindlog-prod-logs-backup-t7-mindlog",
          "arn:aws:s3:::t7-mindlog-prod-logs-backup-t7-mindlog/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_access" {
  name = "${local.name_prefix}-bedrock-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "bedrock:InvokeModel"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

###############################
# SIEM Security Groups
###############################

resource "aws_security_group" "siem_ec2" {
  name        = "${local.name_prefix}-siem-ec2-sg"
  description = "Security group for SIEM target EC2"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-siem-ec2-sg"
  })
}

resource "aws_security_group" "siem_ecs" {
  name        = "${local.name_prefix}-siem-ecs-sg"
  description = "Security group for SIEM Logstash ECS"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-siem-ecs-sg"
  })
}

resource "aws_security_group" "siem_opensearch" {
  name        = "${local.name_prefix}-siem-os-sg"
  description = "Security group for SIEM OpenSearch"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.siem_ecs.id]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-siem-os-sg"
  })
}

###############################
# SIEM IAM Roles
###############################

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "cw_to_kinesis" {
  name = "${local.name_prefix}-cw-to-kinesis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cw_to_kinesis" {
  name = "${local.name_prefix}-cw-to-kinesis-policy"
  role = aws_iam_role.cw_to_kinesis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "kinesis:PutRecord"
        Effect   = "Allow"
        Resource = aws_kinesis_stream.siem.arn
      }
    ]
  })
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${local.name_prefix}-siem-ecs-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${local.name_prefix}-siem-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "${local.name_prefix}-siem-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:DescribeStream",
          "kinesis:ListStreams"
        ]
        Effect   = "Allow"
        Resource = aws_kinesis_stream.siem.arn
      },
      {
        Action   = "es:ESHttpPost"
        Effect   = "Allow"
        Resource = "${aws_opensearch_domain.siem.arn}/*"
      }
    ]
  })
}

###############################
# SIEM Pipeline Resources
###############################

# Kinesis
resource "aws_kinesis_stream" "siem" {
  name             = "${local.name_prefix}-siem-stream"
  shard_count      = 1
  retention_period = 24

  tags = var.tags
}

# CloudWatch
resource "aws_cloudwatch_log_group" "ec2_logs" {
  name              = "/aws/ec2/webserver"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/logstash"
  retention_in_days = 30
}

resource "aws_flow_log" "siem" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = var.vpc_id
}

resource "aws_cloudwatch_log_subscription_filter" "ec2" {
  name            = "${local.name_prefix}-ec2-to-kinesis"
  role_arn        = aws_iam_role.cw_to_kinesis.arn
  log_group_name  = aws_cloudwatch_log_group.ec2_logs.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_stream.siem.arn
}

resource "aws_cloudwatch_log_subscription_filter" "vpc" {
  name            = "${local.name_prefix}-vpc-to-kinesis"
  role_arn        = aws_iam_role.cw_to_kinesis.arn
  log_group_name  = aws_cloudwatch_log_group.vpc_flow_logs.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_stream.siem.arn
}

# OpenSearch
resource "aws_opensearch_domain" "siem" {
  domain_name    = "${var.project}-siem"
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
    subnet_ids         = [var.private_subnet_ids[0]]
    security_group_ids = [aws_security_group.siem_opensearch.id]
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "es:*"
        Resource  = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.project}-siem/*"
      }
    ]
  })

  tags = var.tags
}

# ECS Logstash
resource "aws_ecs_cluster" "siem" {
  name = "${local.name_prefix}-siem-cluster"
}

resource "aws_ecs_task_definition" "logstash" {
  family                   = "${local.name_prefix}-logstash"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "logstash"
      image     = "opensearchproject/logstash-oss-with-opensearch-output-plugin:latest"
      essential = true
      
      environment = [
        { name = "XPACK_MONITORING_ENABLED", value = "false" },
        { name = "CONFIG_STRING", value = "input { kinesis { kinesis_stream_name => '${aws_kinesis_stream.siem.name}' region => '${data.aws_region.current.name}' } } output { opensearch { hosts => ['https://${aws_opensearch_domain.siem.endpoint}:443'] index => 'siem-logs-%%{+YYYY.MM.dd}' ssl => true ssl_certificate_verification => false } }" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "logstash" {
  name            = "${local.name_prefix}-logstash-service"
  cluster         = aws_ecs_cluster.siem.id
  task_definition = aws_ecs_task_definition.logstash.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.siem_ecs.id]
    assign_public_ip = false
  }
}

# S3 Archive
resource "aws_s3_bucket" "siem_archive" {
  bucket = "${local.name_prefix}-siem-log-archive"
  
  tags = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "siem_archive" {
  bucket = aws_s3_bucket.siem_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

###############################
# Helpers & Outputs
###############################

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

variable "private_subnet_ids" {
  type    = list(string)
  default = []
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "siem_ec2_sg_id" {
  value = aws_security_group.siem_ec2.id
}
