# Application Load Balancer with Blue/Green Target Groups
# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb

# ALB — public-facing, spans both public subnets
resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Target Group — Blue
resource "aws_lb_target_group" "blue" {
  name        = "${var.project_name}-tg-blue"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip" # required for Fargate awsvpc networking

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-tg-blue"
    Environment = var.environment
    ManagedBy   = "terraform"
    Color       = "blue"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group — Green
resource "aws_lb_target_group" "green" {
  name        = "${var.project_name}-tg-green"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-tg-green"
    Environment = var.environment
    ManagedBy   = "terraform"
    Color       = "green"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener on port 80 — routes 100% of traffic to blue by default
# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = 100
      }

      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = 0
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-listener-http"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
