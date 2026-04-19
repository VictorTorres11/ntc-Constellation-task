# ECS Cluster, Task Definition, and Blue/Green Services
# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service

# ECS Cluster (Fargate)
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"

  tags = {
    Name        = "${var.project_name}-cluster"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Log Group for ECS task logs
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# references ECR image via variable
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "api"
      image = "${var.ecr_repository_url}:${var.app_image_tag}"

      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name        = "${var.project_name}-task"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ECS Service — Blue
resource "aws_ecs_service" "blue" {
  name            = "${var.project_name}-service-blue"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "api"
    container_port   = var.app_port
  }

  # Ignore task_definition changes — managed by blue-green deploy script
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Name        = "${var.project_name}-service-blue"
    Environment = var.environment
    ManagedBy   = "terraform"
    Color       = "blue"
  }

  depends_on = [aws_lb_listener.http]
}

# ECS Service — Green
resource "aws_ecs_service" "green" {
  name            = "${var.project_name}-service-green"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.green.arn
    container_name   = "api"
    container_port   = var.app_port
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Name        = "${var.project_name}-service-green"
    Environment = var.environment
    ManagedBy   = "terraform"
    Color       = "green"
  }

  depends_on = [aws_lb_listener.http]
}
