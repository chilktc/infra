# --- EC2 Web Server ---
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "${var.project_name}-web-server"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello World from SIEM Target" > /var/www/html/index.html
              # Note: CloudWatch Agent installation would typically be here or via SSM
              EOF
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "siem" {
  name = "${var.project_name}-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "siem" {
  cluster_name = aws_ecs_cluster.siem.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# --- ECS Task Definition (Logstash) ---
resource "aws_ecs_task_definition" "logstash" {
  family                   = "${var.project_name}-logstash"
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
        { name = "CONFIG_STRING", value = "input { kinesis { kinesis_stream_name => '${aws_kinesis_stream.siem_stream.name}' region => '${var.aws_region}' } } output { opensearch { hosts => ['https://${aws_opensearch_domain.siem.endpoint}:443'] index => 'siem-logs-%%{+YYYY.MM.dd}' ssl => true ssl_certificate_verification => false } }" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/logstash"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# --- ECS Service ---
resource "aws_ecs_service" "logstash" {
  name            = "${var.project_name}-logstash-service"
  cluster         = aws_ecs_cluster.siem.id
  task_definition = aws_ecs_task_definition.logstash.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  depends_on = [aws_nat_gateway.nat]
}
