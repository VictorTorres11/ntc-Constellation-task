output "vpc_id" {
  description = "ID VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs private subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "ID NAT Gateway"
  value       = aws_nat_gateway.this.id
}

output "alb_dns_name" {
  description = "DNS name ALB"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN ALB"
  value       = aws_lb.this.arn
}

output "alb_listener_arn" {
  description = "ARN HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "target_group_blue_arn" {
  description = "ARN blue Target Group"
  value       = aws_lb_target_group.blue.arn
}

output "target_group_green_arn" {
  description = "ARN green Target Group"
  value       = aws_lb_target_group.green.arn
}

output "ecs_cluster_name" {
  description = "Name ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "ecs_cluster_arn" {
  description = "ARN ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "ecs_service_blue_name" {
  description = "Name blue ECS service"
  value       = aws_ecs_service.blue.name
}

output "ecs_service_green_name" {
  description = "Name green ECS service"
  value       = aws_ecs_service.green.name
}

output "task_definition_arn" {
  description = "ARN ECS task definition"
  value       = aws_ecs_task_definition.app.arn
}
