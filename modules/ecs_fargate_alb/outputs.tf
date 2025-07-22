output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = var.create_alb ? module.alb[0].dns_name : null
}

output "ecr_repository_url" {
  description = "URL of the created ECR repository"
  value       = var.create_ecr ? module.ecr_repository[0].repository_url : null
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = keys(module.ecs.services)[0]
}

output "github_oidc_role_arn" {
  description = "ARN of the GitHub Actions OIDC IAM Role"
  value       = var.create_gha_role ? aws_iam_role.gha_ecr_role[0].arn : null
}
