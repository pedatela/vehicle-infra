output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "Cluster ECS compartilhado"
}

output "core_alb_dns" {
  value       = aws_lb.service["core"].dns_name
  description = "DNS público do Core"
}

output "sales_alb_dns" {
  value       = aws_lb.service["sales"].dns_name
  description = "DNS público do Sales"
}

output "core_service_name" {
  value       = aws_ecs_service.service["core"].name
  description = "Serviço ECS do Core"
}

output "sales_service_name" {
  value       = aws_ecs_service.service["sales"].name
  description = "Serviço ECS do Sales"
}

output "core_ecr_repository_url" {
  value       = aws_ecr_repository.service["core"].repository_url
  description = "URL do repositório ECR do Core"
}

output "sales_ecr_repository_url" {
  value       = aws_ecr_repository.service["sales"].repository_url
  description = "URL do repositório ECR do Sales"
}

output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.this.id
  description = "ID do User Pool Cognito"
}

output "cognito_user_pool_client_id" {
  value       = aws_cognito_user_pool_client.this.id
  description = "ID do App Client do Cognito"
}

output "cognito_domain" {
  value       = aws_cognito_user_pool_domain.this.domain
  description = "Subdomínio público do Cognito Hosted UI"
}

output "sales_internal_sync_token" {
  value       = local.sales_sync_token
  description = "Token interno compartilhado entre Core e Sales"
}
