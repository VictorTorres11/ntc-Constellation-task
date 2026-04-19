output "github_actions_role_arn" {
  description = "ARN IAM Role assumed by GitHub Actions via OIDC — set as AWS_ROLE_ARN secret in the repository"
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
