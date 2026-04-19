# ntc-Constellation — DevOps Blue-Green Challenge

Blue-green deployment for an ASP.NET Core 8 API on AWS ECS Fargate. Infrastructure via Terraform, pipeline via GitHub Actions.

---

## Stage 0 — Terraform Remote State Bootstrap

One-time setup. Creates the S3 bucket and DynamoDB table used as Terraform remote backend across all modules. Run this before any `terraform init`.

### Prerequisites

- AWS CLI >= 2.0 configured with credentials
- AWS permissions: `s3:CreateBucket`, `s3:PutBucketVersioning`, `s3:PutEncryptionConfiguration`, `s3:PutPublicAccessBlock`, `dynamodb:CreateTable`

### Commands

```powershell
# Windows PowerShell
aws s3api create-bucket --bucket "ntc-constellation-tfstate" --region "us-west-1" --create-bucket-configuration LocationConstraint="us-west-1"
aws s3api put-bucket-versioning --bucket "ntc-constellation-tfstate" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "ntc-constellation-tfstate" --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}'
aws s3api put-public-access-block --bucket "ntc-constellation-tfstate" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws dynamodb create-table --table-name "terraform-locks" --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region "us-west-1"
```

After this, every `terraform init` in `infra/ecr`, `infra/ecs`, and `infra/pipeline` will automatically use the S3 backend and DynamoDB lock.

### References

- https://developer.hashicorp.com/terraform/language/backend/s3
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-bucket.html
- https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/getting-started-step-1.html

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
aws_region      = "us-west-1"
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
aws_region         = "us-west-1"
project_name       = "ntc-constellation"
environment        = "dev"
vpc_cidr           = "10.0.0.0/16"
ecr_repository_url = "<account>.dkr.ecr.us-west-1.amazonaws.com/ntc-constellation-api"
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
