# OIDC Provider + IAM Role for GitHub Actions — least privilege
# Ref: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint for token.actions.githubusercontent.com (stable, published by GitHub)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "${var.project_name}-github-oidc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Restrict to the configured GitHub org/repo; wildcards allow any branch/tag
      values = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name        = "${var.project_name}-github-actions-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Minimal policy: ECR push + ECS deploy
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid       = "ECRAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR image push scoped to the specific repository
  statement {
    sid = "ECRPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"]
  }

  # ECS: register new task definition revision + describe
  statement {
    sid = "ECSRegisterTaskDefinition"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  # ECS: update and describe services scoped to this project's cluster
  statement {
    sid = "ECSUpdateService"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeClusters",
    ]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}",
      "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${var.project_name}/*",
    ]
  }

  # ALB: describe and modify listener rules for blue-green traffic switching
  statement {
    sid = "ALBTrafficSwitch"
    actions = [
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:DescribeTargetHealth",
    ]
    resources = ["*"]
  }

  # PassRole: required so GitHub Actions can pass ECS roles when registering task definitions
  statement {
    sid     = "PassECSRoles"
    actions = ["iam:PassRole"]
    resources = [
      var.ecs_execution_role_arn,
      var.ecs_task_role_arn,
    ]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.project_name}-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
