locals {
  tags            = { Project = var.project_name }
  rds_mode_suffix = var.rds_publicly_accessible ? "pub" : "priv"
  rds_subnet_ids = (
    var.rds_publicly_accessible
    ? values(aws_subnet.public)[*].id
    : values(aws_subnet.private)[*].id
  )
  services = {
    core = {
      container_port = var.core_app_container_port
      desired_count  = var.core_app_desired_count
      image_override = var.core_app_container_image
    }
    sales = {
      container_port = var.sales_app_container_port
      desired_count  = var.sales_app_desired_count
      image_override = var.sales_app_container_image
    }
  }
}

resource "aws_ecr_repository" "service" {
  for_each             = local.services
  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.tags
}

resource "aws_subnet" "public" {
  for_each = {
    a = "10.0.1.0/24"
    b = "10.0.2.0/24"
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "${var.aws_region}${each.key}"
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "public-${each.key}" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = local.tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = local.tags
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  for_each = {
    a = "10.0.11.0/24"
    b = "10.0.12.0/24"
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = "${var.aws_region}${each.key}"
  tags              = merge(local.tags, { Name = "private-${each.key}" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "private" })
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  for_each    = local.services
  name        = "${var.project_name}-${each.key}-alb"
  description = "ALB ingress ${each.key}"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Service = each.key })
}

resource "aws_security_group" "service" {
  for_each    = local.services
  name        = "${var.project_name}-${each.key}-svc"
  description = "ECS tasks ${each.key}"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol        = "tcp"
    from_port       = each.value.container_port
    to_port         = each.value.container_port
    security_groups = [aws_security_group.alb[each.key].id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Service = each.key })
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds"
  description = "Acesso PostgreSQL para ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [for sg in aws_security_group.service : sg.id]
  }

  dynamic "ingress" {
    for_each = var.rds_publicly_accessible ? [1] : []

    content {
      protocol    = "tcp"
      from_port   = 5432
      to_port     = 5432
      cidr_blocks = var.rds_allowed_cidrs
    }
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_lb" "service" {
  for_each           = local.services
  name               = substr("${var.project_name}-${each.key}-alb", 0, 32)
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[each.key].id]
  subnets            = values(aws_subnet.public)[*].id
  tags               = merge(local.tags, { Service = each.key })
}

resource "aws_lb_target_group" "service" {
  for_each    = local.services
  name        = substr("${var.project_name}-${each.key}-tg", 0, 32)
  port        = each.value.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    path                = "/"
  }

  tags = merge(local.tags, { Service = each.key })
}

resource "aws_lb_listener" "service" {
  for_each          = local.services
  load_balancer_arn = aws_lb.service[each.key].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  tags = local.tags
}

resource "aws_cloudwatch_log_group" "service" {
  for_each          = local.services
  name              = "/ecs/${var.project_name}-${each.key}"
  retention_in_days = 7
  tags              = merge(local.tags, { Service = each.key })
}

resource "aws_iam_role" "task_execution" {
  name = "${var.project_name}-ecs-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_role" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${var.project_name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "random_password" "sales_sync_token" {
  length  = 24
  upper   = true
  numeric = true
  special = false
}

resource "random_password" "rds" {
  for_each = local.services
  length   = 24
  upper    = true
  numeric  = true
  special  = false
}

locals {
  sales_sync_token = var.sales_internal_sync_token != "" ? var.sales_internal_sync_token : random_password.sales_sync_token.result
  rds_passwords = {
    for service_name in keys(local.services) :
    service_name => (var.rds_password != "" ? var.rds_password : random_password.rds[service_name].result)
  }
  rds_db_names = {
    for service_name in keys(local.services) :
    service_name => lower(substr(replace("${var.rds_db_name}${service_name}", "-", ""), 0, 63))
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-rds-subnets-${var.rds_publicly_accessible ? "public" : "private"}"
  subnet_ids = local.rds_subnet_ids
  tags       = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "service" {
  for_each                     = local.services
  identifier                   = "${var.project_name}-${each.key}-postgres-${local.rds_mode_suffix}"
  allocated_storage            = var.rds_allocated_storage
  max_allocated_storage        = var.rds_max_allocated_storage
  engine                       = "postgres"
  instance_class               = var.rds_instance_class
  db_name                      = local.rds_db_names[each.key]
  username                     = var.rds_username
  password                     = local.rds_passwords[each.key]
  db_subnet_group_name         = aws_db_subnet_group.main.name
  vpc_security_group_ids       = [aws_security_group.rds.id]
  publicly_accessible          = var.rds_publicly_accessible
  multi_az                     = var.rds_multi_az
  skip_final_snapshot          = var.rds_skip_final_snapshot
  deletion_protection          = false
  backup_retention_period      = var.rds_backup_retention_period
  auto_minor_version_upgrade   = true
  apply_immediately            = true
  performance_insights_enabled = false
  tags                         = merge(local.tags, { Service = each.key })

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [aws_db_subnet_group.main]
  }
}

resource "aws_ecs_task_definition" "service" {
  for_each                 = local.services
  family                   = "${var.project_name}-${each.key}"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-${each.key}"
      image     = each.value.image_override != "" ? each.value.image_override : "${aws_ecr_repository.service[each.key].repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = each.value.container_port
        hostPort      = each.value.container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service[each.key].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "${var.project_name}-${each.key}"
        }
      }
      environment = (
        each.key == "core"
        ? [
          { name = "PORT", value = tostring(var.core_app_container_port) },
          { name = "COGNITO_REGION", value = var.aws_region },
          { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.this.id },
          { name = "COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.this.id },
          { name = "COGNITO_ISSUER", value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.this.id}" },
          { name = "AUTH_SELLER_ROLE", value = "seller" },
          { name = "SALES_SERVICE_URL", value = "http://${aws_lb.service["sales"].dns_name}/api" },
          { name = "SALES_SERVICE_TOKEN", value = local.sales_sync_token },
          { name = "DATABASE_HOST", value = aws_db_instance.service[each.key].address },
          { name = "DATABASE_PORT", value = tostring(aws_db_instance.service[each.key].port) },
          { name = "DATABASE_NAME", value = local.rds_db_names[each.key] },
          { name = "DATABASE_USER", value = var.rds_username },
          { name = "DATABASE_PASSWORD", value = local.rds_passwords[each.key] },
          { name = "DATABASE_SSL", value = "true" }
        ]
        : [
          { name = "PORT", value = tostring(var.sales_app_container_port) },
          { name = "COGNITO_REGION", value = var.aws_region },
          { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.this.id },
          { name = "COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.this.id },
          { name = "COGNITO_ISSUER", value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.this.id}" },
          { name = "INTERNAL_SYNC_TOKEN", value = local.sales_sync_token },
          { name = "CORE_SERVICE_URL", value = "http://${aws_lb.service["core"].dns_name}/api" },
          { name = "CORE_SERVICE_TOKEN", value = local.sales_sync_token },
          { name = "DATABASE_HOST", value = aws_db_instance.service[each.key].address },
          { name = "DATABASE_PORT", value = tostring(aws_db_instance.service[each.key].port) },
          { name = "DATABASE_NAME", value = local.rds_db_names[each.key] },
          { name = "DATABASE_USER", value = var.rds_username },
          { name = "DATABASE_PASSWORD", value = local.rds_passwords[each.key] },
          { name = "DATABASE_SSL", value = "true" }
        ]
      )
    }
  ])
}

resource "aws_ecs_service" "service" {
  for_each        = local.services
  name            = "${var.project_name}-${each.key}-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = values(aws_subnet.public)[*].id
    security_groups  = [aws_security_group.service[each.key].id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service[each.key].arn
    container_name   = "${var.project_name}-${each.key}"
    container_port   = each.value.container_port
  }

  tags = merge(local.tags, { Service = each.key })
}

resource "random_string" "cognito_domain_suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-users"

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  tags = local.tags
}

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.project_name}-app-client"
  user_pool_id = aws_cognito_user_pool.this.id

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]
  prevent_user_existence_errors        = "ENABLED"
  access_token_validity                = 60
  id_token_validity                    = 60
  refresh_token_validity               = 30

  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  generate_secret = false

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${var.project_name}-${random_string.cognito_domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.this.id
}
