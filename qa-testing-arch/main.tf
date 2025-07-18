#### ECR Repository ####
module "ecr_repository" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.0"

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
#### ECS IAM Role ####
resource "aws_iam_role" "ecs_role" {
  name = var.ecs_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_full" {
  name        = var.ecs_custom_policy_name
  description = var.ecs_custom_policy_description

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = var.ecs_custom_policy_statements
  })
}

resource "aws_iam_role_policy_attachment" "ecs_full_attach" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.ecs_full.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#### Application Load Balancer ####
resource "aws_security_group" "alb_sg" {
  name        = "${var.name}-alb-sg"
  description = "Allow HTTP inbound and all outbound"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.name
  }
}
resource "aws_lb" "alb" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids

  tags = {
    Project = var.name
  }
}
resource "aws_lb_target_group" "ecs_fargate" {
  name_prefix = "ecs"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Project = var.name
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_fargate.arn
  }
}

#### ECS Cluster & Task definition ####
locals {
  ecr_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_name}:${var.image_tag}"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.ecs_log_retention_days
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.1"

  cluster_name = "${var.name}-cluster"

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

      task_exec_iam_role_arn = aws_iam_role.ecs_role.arn
      task_role_arn          = aws_iam_role.ecs_role.arn

      load_balancer = {
        alb = {
          target_group_arn = aws_lb_target_group.ecs_fargate.arn
          container_name   = var.ecs_container_name
          container_port   = 80
        }
      }

      runtime_platform = {
        operating_system_family = var.ecs_operating_system_family
        cpu_architecture        = var.ecs_cpu_architecture
      }

      load_balancers = [
        {
          target_group_arn = aws_lb_target_group.ecs_fargate.arn
          container_name   = var.ecs_container_name
          container_port   = 80
        }
      ]

      container_definitions = {
        "${var.ecs_container_name}" = {
          name               = var.ecs_container_name
          image              = "${local.ecr_image}"
          essential          = true
          memory             = var.ecs_task_memory
          memory_reservation = var.ecs_container_memory_reservation

          log_configuration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = aws_cloudwatch_log_group.ecs_log_group.name
              awslogs-region        = var.region
              awslogs-stream-prefix = var.ecs_container_name
            }
          }

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
          source_security_group_id = aws_security_group.alb_sg.id
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
  for_each    = local.passrole_policies
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
  for_each   = aws_iam_policy.passrole
  role       = aws_iam_role.gha_ecr_role.name
  policy_arn = each.value.arn
}