locals {
  name_prefix = "${var.project}-${var.env}"
}

variable "project" {}
variable "env" {}
variable "vpc_id" {}
variable "public_subnet_ids" {}
variable "instance_ids" {}
variable "management_instance_ids" {}
variable "frontend_instance_ids" {}
variable "security_group_ids" {}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.public_subnet_ids
  enable_deletion_protection = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "app" {
  name     = "${local.name_prefix}-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-app-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/actuator/*"]
    }
  }
}

resource "aws_lb_listener_rule" "frontend_root" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_target_group_attachment" "app" {
  for_each         = var.instance_ids
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = each.value
  port             = 8080
}

###############################
# Grafana (3001)
###############################
resource "aws_lb_target_group" "grafana" {
  name     = "${local.name_prefix}-grafana-tg"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-grafana-tg"
  })
}

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.this.arn
  port              = "3001"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

resource "aws_lb_target_group_attachment" "grafana" {
  for_each         = var.management_instance_ids
  target_group_arn = aws_lb_target_group.grafana.arn
  target_id        = each.value
  port             = 3001
}

###############################
# OpenSearch (5601)
###############################
resource "aws_lb_target_group" "opensearch" {
  name     = "${local.name_prefix}-os-tg"
  port     = 5601
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/api/status"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-302,401"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-os-tg"
  })
}

resource "aws_lb_listener" "opensearch" {
  load_balancer_arn = aws_lb.this.arn
  port              = "5601"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.opensearch.arn
  }
}

resource "aws_lb_target_group_attachment" "opensearch" {
  for_each         = var.management_instance_ids
  target_group_arn = aws_lb_target_group.opensearch.arn
  target_id        = each.value
  port             = 5601
}

###############################
# Frontend (3000)
###############################
resource "aws_lb_target_group" "frontend" {
  name     = "${local.name_prefix}-frontend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-frontend-tg"
  })
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.this.arn
  port              = "3000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_target_group_attachment" "frontend" {
  for_each         = var.frontend_instance_ids
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = each.value
  port             = 3000
}
