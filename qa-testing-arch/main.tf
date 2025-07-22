module "ecs_fargate_alb" {
  source = "../modules/ecs_fargate_alb"

  #### Global ####
  region = var.region
  name   = var.name

  #### ECR ####
  ecr_name              = var.ecr_name
  image_scanning        = var.image_scanning
  tag_immutability      = var.tag_immutability
  lifecycle_expire_days = var.lifecycle_expire_days

  #### ALB ####
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  #### ECS Task ####
  ecs_task_cpu                   = var.ecs_task_cpu
  ecs_task_memory                = var.ecs_task_memory
  ecs_container_memory_reservation = var.ecs_container_memory_reservation
  ecs_container_name             = var.ecs_container_name
  image_tag                      = var.image_tag
  ecs_operating_system_family    = var.ecs_operating_system_family
  ecs_cpu_architecture           = var.ecs_cpu_architecture

  #### GitHub Actions ####
  gha_role_name         = var.gha_role_name
  github_oidc_sub       = var.github_oidc_sub
  passrole_role_names   = var.passrole_role_names
}
