#### Global ####
region = "eu-west-3" ## update this
name = "qa-mobile-testing"
#### ECR Repository ####
ecr_name                = "qa/mobile/testing"
image_scanning          = false
tag_immutability        = "MUTABLE"
lifecycle_expire_days   = 90
#### ECS IAM Role ####
ecs_role_name                 = "qa.mobile.testing"
ecs_custom_policy_name        = "ECS.Full"
ecs_custom_policy_description = "Full access placeholder for ECS (to be updated)"
ecs_custom_policy_statements = [
  {
    Effect   = "Allow",
    Action   = ["ecs:*"],
    Resource = "*"
  }
]
#### ALB ####
vpc_id = "vpc-0a47c5e097a02e653"
#### ECS Task Definition ####
ecs_task_cpu                   = 2048
ecs_task_memory                = 5120
ecs_container_memory_reservation = 4096
ecs_container_name             = "qa-mobile-testing"
image_tag                      = "latest"
ecs_log_retention_days = 7
ecs_operating_system_family    = "LINUX"
ecs_cpu_architecture           = "X86_64"
subnet_ids                     = ["subnet-091d4d7a7980a6a8d", "subnet-014817b95e367b258"] ## update this
#### GHActions Role ####
gha_role_name              = "GHActions-ECR"
github_oidc_sub           = "repo:midwest-tape/internal-epub-ingest:*"
passrole_role_names =  [
    "dnet_AudioIngestRole",
    "dnet_ComicIngestRole",
    "dnet_EpubIngestRole"
  ]
