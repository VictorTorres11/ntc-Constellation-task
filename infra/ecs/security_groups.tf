# SG to ALB and ECS Tasks

# ALB SG — allows inbound HTTP from internet
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "Allow inbound HTTP (80) from internet"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-alb"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ECS SG — allows inbound only from ALB on app port
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-sg-ecs"
  description = "Allow inbound traffic only from ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "App port from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound (ECR pull, CloudWatch)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-ecs"
    Environment = var.environment
    ManagedBy   = "terraform"
    Color       = "shared"
  }
}
