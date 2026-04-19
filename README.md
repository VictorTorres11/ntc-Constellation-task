# ntc-Constellation — DevOps Blue-Green Challenge

Zero-downtime blue-green deployment pipeline for an ASP.NET Core 8 Web API on AWS ECS Fargate, with infrastructure managed by Terraform and an automated pipeline via GitHub Actions.

---

## Stage 1 — ECR via Terraform

Provisions an ECR repository on AWS using Terraform running locally. The repository stores Docker images with automatic scanning, AES-256 encryption, and lifecycle cleanup of old images.

### Prerequisites

- Terraform
https://developer.hashicorp.com/terraform/install >= 1.0
- AWS CLI
https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html >= 2.0 configured with valid credentials
- Required AWS permissions: `ecr:CreateRepository`, `ecr:PutLifecyclePolicy`, `ecr:DescribeRepositories`

### Configuration

Copy the example file and fill in your values:

```bash
cp infra/ecr/terraform.tfvars.example infra/ecr/terraform.tfvars
```

Edit `infra/ecr/terraform.tfvars`:

```hcl
aws_region      = "us-east-1"
repository_name = "ntc-constellation-api"
environment     = "dev"
```

> `terraform.tfvars` is listed in `.gitignore` and must never be committed.

### Commands

```bash
cd infra/ecr

# Initialize providers
terraform init

# Validate syntax
terraform validate

# Preview changes before applying
terraform plan -var-file="terraform.tfvars"

# Provision the ECR repository
terraform apply -var-file="terraform.tfvars"

# Check outputs
terraform output repository_url
terraform output repository_arn

# Verify idempotency (should return "No changes")
terraform plan -var-file="terraform.tfvars"

# Destroy resources when no longer needed
terraform destroy -var-file="terraform.tfvars"
```

### Resources created

- `aws_ecr_repository` — repository with automatic scan on push and AES-256 encryption
- `aws_ecr_lifecycle_policy` — removes untagged images older than 30 days

### References

- Terraform: aws_ecr_repository
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
- AWS ECR Lifecycle Policies
https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html
- AWS CLI: ECR
https://docs.aws.amazon.com/cli/latest/reference/ecr/index.html

---

## Stage 2 — Docker Build and Push

Builds the ASP.NET Core 8 API image using a multi-stage Dockerfile and pushes it to ECR.

### Prerequisites

- Docker >= 24.0
https://docs.docker.com/get-docker/
- AWS CLI >= 2.0 configured with valid credentials
- ECR repository provisioned (Stage 1)
- Required AWS permissions: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`

### Commands

```bash
# Build the image locally (run from repo root)
docker build -t ntc-constellation-api:local ./app

# Run locally to verify
docker run --rm -p 8080:8080 ntc-constellation-api:local
# Visit http://localhost:8080 and http://localhost:8080/health

```

### Dockerfile stages

- `build` — uses `mcr.microsoft.com/dotnet/sdk:8.0` to restore, compile and publish the app
- `runtime` — uses `mcr.microsoft.com/dotnet/aspnet:8.0` as the minimal runtime image; only the published output is copied

### References

- ASP.NET Core Docker images
https://hub.docker.com/_/microsoft-dotnet-aspnet
- .NET SDK Docker images
https://hub.docker.com/_/microsoft-dotnet-sdk
- Docker multi-stage builds
https://docs.docker.com/build/building/multi-stage/
