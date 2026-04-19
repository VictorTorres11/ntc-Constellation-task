# ntc-Constellation — DevOps Blue-Green Challenge

Blue-green deployment for an ASP.NET Core 8 API on AWS ECS Fargate. Infrastructure via Terraform, pipeline via GitHub Actions.

---

## Stage 1 — ECR via Terraform

Sets up the ECR repository where images will be stored. Scanning on push, AES-256 encryption, and a lifecycle rule to clean up untagged images after 30 days.

### Prerequisites

- Terraform >= 1.0 — https://developer.hashicorp.com/terraform/install
- AWS CLI >= 2.0 — https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
- AWS permissions: `ecr:CreateRepository`, `ecr:PutLifecyclePolicy`, `ecr:DescribeRepositories`

### Configuration

```bash
cp infra/ecr/terraform.tfvars.example infra/ecr/terraform.tfvars
```

```hcl
aws_region      = "us-east-1"
repository_name = "ntc-constellation-api"
environment     = "dev"
```

`terraform.tfvars` is in `.gitignore` — don't commit it.

### Commands

```bash
cd infra/ecr
terraform init
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan

# check outputs
terraform output repository_url
terraform output repository_arn

# second plan should return "No changes"
terraform plan -var-file="terraform.tfvars"

terraform destroy -var-file="terraform.tfvars"
```

### References

- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
- https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html
- https://docs.aws.amazon.com/cli/latest/reference/ecr/index.html

---

## Stage 2 — Docker Build and Push

Multi-stage Dockerfile: SDK image for build, ASP.NET runtime image for the final layer. Push to ECR tagged with the Git SHA.

### Prerequisites

- Docker >= 24.0 — https://docs.docker.com/get-docker/
- AWS CLI >= 2.0 with valid credentials
- ECR repository from Stage 1
- AWS permissions: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`

### Commands

```bash
# build and test locally
docker build -t ntc-constellation-api:local ./app
docker run --rm -p 8080:8080 ntc-constellation-api:local
# http://localhost:8080 and http://localhost:8080/health

# push to ECR
./scripts/ecr-push.sh
```

### References

- https://hub.docker.com/_/microsoft-dotnet-aspnet
- https://hub.docker.com/_/microsoft-dotnet-sdk
- https://docs.docker.com/build/building/multi-stage/
- https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html

---

## Stage 3 — ECS Fargate + ALB

VPC, ECS Fargate cluster, ALB, and two ECS services (blue and green). Blue gets 100% of traffic by default. Green sits on standby until a deploy promotes it.

### Prerequisites

- Terraform >= 1.0 — https://developer.hashicorp.com/terraform/install
- AWS CLI >= 2.0 — https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
- Stages 1 and 2 done (ECR repo exists and has at least one image)
- AWS permissions: `ec2:*`, `ecs:*`, `elasticloadbalancing:*`, `iam:*`, `logs:*`

### Configuration

```bash
cp infra/ecs/terraform.tfvars.example infra/ecs/terraform.tfvars
```

```hcl
aws_region         = "us-east-1"
project_name       = "ntc-constellation"
environment        = "dev"
vpc_cidr           = "10.0.0.0/16"
ecr_repository_url = "<account>.dkr.ecr.us-east-1.amazonaws.com/ntc-constellation-api"
app_image_tag      = "latest"
```

`terraform.tfvars` is in `.gitignore` — don't commit it.

### Commands

```bash
cd infra/ecs
terraform init
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan

terraform output alb_dns_name
terraform output ecs_cluster_name

# verify blue is getting 100% of traffic
./scripts/verify-alb-traffic-distribution.sh

terraform destroy -var-file="terraform.tfvars"
```

### References

- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
- https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html
