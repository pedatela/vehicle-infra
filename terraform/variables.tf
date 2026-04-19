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
