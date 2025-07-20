#### ECR Repository ####
module "ecr_repository" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.0"
  count  = var.create_ecr ? 1 : 0
  repository_name = var.ecr_name

  repository_image_scan_on_push = var.image_scanning
  repository_image_tag_mutability = var.tag_immutability

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire untagged images older than ${var.lifecycle_expire_days} days",
        selection = {
          tagStatus     = "untagged",
          countType     = "sinceImagePushed",
          countUnit     = "days",
          countNumber   = var.lifecycle_expire_days
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}

#### Application Load Balancer ####
module "alb" {
  source = "terraform-aws-modules/alb/aws"
  count  = var.create_alb ? 1 : 0
  name    = "${var.name}-alb"
  vpc_id  = var.vpc_id
  subnets = var.subnet_ids
  enable_deletion_protection = false

  security_group_ingress_rules = {
    allow_http = {
        description = "Allow HTTP"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_ipv4 = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    allow_all = {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_ipv4 = "0.0.0.0/0"
    }
  }
  target_groups = {
    "${var.name}-ecs" = {
        name_prefix      = "ecs"
        backend_protocol = "HTTP"
        backend_port     = 80
        target_type      = "ip"
        create_attachment = false 
        health_check = {
        enabled             = true
        path                = "/"
        matcher             = "200"
    }
  }
}

  listeners = {
    http_tcp_listeneres = {
      port = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "${var.name}-ecs"
      }
    }
  }
}

#### ECS Cluster & Task definition ####
locals {
  ecr_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_name}:${var.image_tag}"
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.1"

  cluster_name = "${var.name}-cluster"
  create_task_exec_iam_role	= true
  create_task_exec_policy = true
  create_cloudwatch_log_group = true
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 1
      }
    }
  }

  services = {
    "${var.name}-service" = {
      launch_type   = "FARGATE"
      cpu           = var.ecs_task_cpu
      memory        = var.ecs_task_memory
      desired_count = 1


      load_balancer = {
        alb = {
          target_group_arn = module.alb.target_groups["${var.name}-ecs"].arn
          container_name   = var.ecs_container_name
          container_port   = 80
        }
      }

      runtime_platform = {
        operating_system_family = var.ecs_operating_system_family
        cpu_architecture        = var.ecs_cpu_architecture
      }

      container_definitions = {
        "${var.ecs_container_name}" = {
          name               = var.ecs_container_name
          image              = "${local.ecr_image}"
          essential          = true
          memory             = var.ecs_task_memory
          memory_reservation = var.ecs_container_memory_reservation


          port_mappings = [
            {
              containerPort = 80
              protocol      = "tcp"
            }
          ]
        }
      }

      subnet_ids = var.subnet_ids

      security_group_rules = {
        alb_ingress = {
          type                     = "ingress"
          from_port                = 80
          to_port                  = 80
          protocol                 = "tcp"
          source_security_group_id = module.alb.security_group_id
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }
}


#### GHActions Role ####
locals {
  passrole_policies = {
    for role_name in var.passrole_role_names :
    "PassRole.${role_name}" => "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${role_name}"
  }
    github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

}
resource "aws_iam_role" "gha_ecr_role" {
  name = var.gha_role_name
  count  = var.create_gha_role ? 1 : 0
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Principal: {
          Federated: local.github_oidc_provider_arn
        },
        Action: "sts:AssumeRoleWithWebIdentity",
        Condition: {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          },
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.github_oidc_sub
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "passrole" {
  for_each    = var.create_gha_role ? local.passrole_policies : {}
  name        = each.key
  description = "Allow passing role ${each.key}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid     = "IAMPassRole",
        Effect  = "Allow",
        Action  = "iam:PassRole",
        Resource = each.value
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "passrole_attach" {
  for_each   = var.create_gha_role ? aws_iam_policy.passrole : {}
  role       = aws_iam_role.gha_ecr_role.name
  policy_arn = each.value.arn
}