# ECS Fargate with ALB and ECR Terraform Module

This Terraform module creates a complete container deployment stack on AWS using:

- **ECS Fargate** for container orchestration
- **Application Load Balancer (ALB)** for traffic routing
- **ECR** for container image storage
- Optional **IAM role for GitHub Actions** with OIDC authentication

This module is designed to be **reusable and configurable** across multiple environments.

---

## Example Usage

```hcl
module "ecs_fargate_alb" {
  source  = "path/to/modules/ecs_fargate_alb"

  name                       = "my-app"
  vpc_id                     = "vpc-123456"
  subnet_ids                 = ["subnet-abc", "subnet-def"]
  region                     = "us-east-1"

  ecr_name                   = "my-app-repo"
  image_tag                  = "latest"
  image_scanning             = true
  tag_immutability           = "IMMUTABLE"
  lifecycle_expire_days      = 30

  ecs_task_cpu               = 256
  ecs_task_memory            = 512
  ecs_container_memory_reservation = 256
  ecs_container_name         = "my-app-container"
  ecs_operating_system_family = "LINUX"
  ecs_cpu_architecture       = "X86_64"

  create_gha_role            = true
  gha_role_name              = "gha-my-app-role"
  github_oidc_sub            = "repo:my-org/my-app:*"
  passrole_role_names        = ["EcsExecutionRole"]
}
```

## Inputs

| Name                               | Type           | Default       | Description                                     |
| ---------------------------------- | -------------- | ------------- | ----------------------------------------------- |
| `region`                           | `string`       | `"us-east-1"` | AWS Region                                      |
| `name`                             | `string`       | n/a           | Global name prefix for resources                |
| `vpc_id`                           | `string`       | n/a           | VPC ID for ECS and ALB                          |
| `subnet_ids`                       | `list(string)` | n/a           | Subnet IDs for ECS and ALB                      |
| `create_ecr`                       | `bool`         | `true`        | Whether to create an ECR repository             |
| `ecr_name`                         | `string`       | n/a           | Name of the ECR repository                      |
| `image_scanning`                   | `bool`         | `false`       | Enable image scanning on push                   |
| `tag_immutability`                 | `string`       | n/a           | Image tag mutability (`MUTABLE` or `IMMUTABLE`) |
| `lifecycle_expire_days`            | `number`       | n/a           | Days before untagged images expire              |
| `image_tag`                        | `string`       | `"latest"`    | Tag of the image to deploy                      |
| `ecs_task_cpu`                     | `number`       | n/a           | ECS task vCPU units                             |
| `ecs_task_memory`                  | `number`       | n/a           | ECS task memory (MiB)                           |
| `ecs_container_memory_reservation` | `number`       | n/a           | Container soft memory reservation               |
| `ecs_container_name`               | `string`       | n/a           | ECS container name                              |
| `ecs_operating_system_family`      | `string`       | n/a           | ECS runtime OS (e.g., LINUX)                    |
| `ecs_cpu_architecture`             | `string`       | n/a           | CPU architecture (e.g., X86_64)                 |
| `create_gha_role`                  | `bool`         | `true`        | Whether to create a GitHub Actions IAM role     |
| `gha_role_name`                    | `string`       | n/a           | IAM role name for GitHub OIDC                   |
| `github_oidc_sub`                  | `string`       | n/a           | GitHub OIDC subject (e.g. `repo:org/repo:*`)    |
| `passrole_role_names`              | `list(string)` | `[]`          | List of IAM roles to allow `iam:PassRole`       |
| `create_alb`                       | `bool`         | `true`        | optionally control ALB creation                 |

## outputs:

| Name                   | Description                                      |
| ---------------------- | ------------------------------------------------ |
| `alb_dns_name`         | DNS name of the ALB                              |
| `ecr_repository_url`   | URL of the created ECR repository                |
| `ecs_cluster_name`     | Name of the ECS cluster                          |
| `ecs_service_name`     | Name of the ECS service                          |
| `github_oidc_role_arn` | ARN of the GitHub Actions OIDC role (if created) |
