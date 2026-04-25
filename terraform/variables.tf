variable "project_name" {
  description = "Projeto/identificador base"
  type        = string
  default     = "postech-app"
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "core_app_container_image" {
  description = "Imagem (URI) utilizada pelo serviço Core; vazio usa o ECR criado aqui"
  type        = string
  default     = ""
}

variable "core_app_container_port" {
  description = "Porta exposta pelo Core"
  type        = number
  default     = 3000
}

variable "core_app_desired_count" {
  description = "Número de tasks ECS para o Core"
  type        = number
  default     = 1
}

variable "sales_app_container_image" {
  description = "Imagem (URI) utilizada pelo serviço Sales"
  type        = string
  default     = ""
}

variable "sales_app_container_port" {
  description = "Porta exposta pelo Sales"
  type        = number
  default     = 4000
}

variable "sales_app_desired_count" {
  description = "Número de tasks ECS para o Sales"
  type        = number
  default     = 1
}

variable "cognito_callback_urls" {
  description = "Lista de URLs de callback autorizadas no Cognito"
  type        = list(string)
  default = [
    "http://localhost:3000/callback"
  ]
}

variable "cognito_logout_urls" {
  description = "Lista de URLs de logout autorizadas no Cognito"
  type        = list(string)
  default = [
    "http://localhost:3000/logout"
  ]
}

variable "sales_internal_sync_token" {
  description = "Token compartilhado entre Core e Sales; deixe vazio para gerar um aleatório"
  type        = string
  default     = ""
  sensitive   = true
}

variable "rds_instance_class" {
  description = "Classe da instância RDS PostgreSQL"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "Armazenamento inicial do RDS (GB)"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Armazenamento máximo autoscaling do RDS (GB)"
  type        = number
  default     = 20
}

variable "rds_db_name" {
  description = "Prefixo do nome do banco PostgreSQL (core/sales será concatenado)"
  type        = string
  default     = "postechapp"
}

variable "rds_username" {
  description = "Usuário master do PostgreSQL"
  type        = string
  default     = "postechadmin"
}

variable "rds_password" {
  description = "Senha do usuário master; deixe vazio para gerar automaticamente"
  type        = string
  default     = ""
  sensitive   = true
}

variable "rds_multi_az" {
  description = "Habilita deployment Multi-AZ no RDS"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Dias de retenção de backup automático (0 desabilita)"
  type        = number
  default     = 0
}

variable "rds_skip_final_snapshot" {
  description = "Pula snapshot final ao destruir o RDS"
  type        = bool
  default     = true
}

variable "rds_publicly_accessible" {
  description = "Define se o RDS será público para conexão direta externa"
  type        = bool
  default     = true
}

variable "rds_allowed_cidrs" {
  description = "CIDRs liberados para acesso externo ao RDS quando público"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
