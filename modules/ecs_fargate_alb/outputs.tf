# output "alb_dns_name" {
#   value = aws_lb.alb.dns_name
# }

output "cluster_name" {
  value = module.ecs.cluster_name
}

output "service_name" {
  value = module.ecs.services["${var.name}-service"].name
}