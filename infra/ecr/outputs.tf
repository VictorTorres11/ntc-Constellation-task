# expose repository URI and ARN
output "repository_url" {
  description = "URI of the ECR repo"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repo"
  value       = aws_ecr_repository.this.arn
}
