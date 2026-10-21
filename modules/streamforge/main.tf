locals {
  name = "${var.project_name}-${var.environment}"
}
module "vpc" {
  source               = "../vpc"
  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}
resource "aws_ecr_repository" "images" {
  for_each             = toset(["frontend", "backend"])
  name                 = "${local.name}-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
resource "aws_ecs_cluster" "main" {
  name = local.name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${local.name}"
  retention_in_days = 30
}
resource "aws_security_group" "alb" {
  name   = "${local.name}-alb"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 8096
    to_port     = 8096
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "tasks" {
  name   = "${local.name}-tasks"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 8096
    to_port         = 8096
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "efs" {
  name   = "${local.name}-efs"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.tasks.id]
  }
}
resource "aws_efs_file_system" "main" {
  encrypted      = true
  creation_token = local.name
  lifecycle { prevent_destroy = true }
}
resource "aws_efs_backup_policy" "main" {
  file_system_id = aws_efs_file_system.main.id
  backup_policy { status = "ENABLED" }
}
resource "aws_efs_mount_target" "main" {
  count           = length(var.private_subnet_cidrs)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = module.vpc.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}
resource "aws_efs_access_point" "data" {
  for_each       = toset(["config", "data", "media"])
  file_system_id = aws_efs_file_system.main.id
  posix_user {
    uid = 1000
    gid = 1000
  }
  root_directory {
    path = "/${each.key}"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0750"
    }
  }
}
resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = aws_iam_role.execution.assume_role_policy
}
resource "aws_iam_role_policy" "efs" {
  role   = aws_iam_role.task.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"], Resource = aws_efs_file_system.main.arn }] })
}
resource "aws_ecs_task_definition" "main" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  dynamic "volume" {
    for_each = aws_efs_access_point.data
    content {
      name = volume.key
      efs_volume_configuration {
        file_system_id     = aws_efs_file_system.main.id
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = volume.value.id
          iam             = "ENABLED"
        }
      }
    }
  }
  container_definitions = jsonencode([
    {
      name         = "backend", image = var.backend_image, essential = true,
      user         = "1000:1000",
      portMappings = [{ containerPort = 8096, protocol = "tcp" }],
      environment = [
        { name = "JELLYFIN_CONFIG_DIR", value = "/config" },
        { name = "JELLYFIN_DATA_DIR", value = "/data" },
        { name = "JELLYFIN_CACHE_DIR", value = "/tmp/cache" },
        { name = "JELLYFIN_NOWEBCONTENT", value = "true" }
      ],
      mountPoints      = [for name in ["config", "data", "media"] : { sourceVolume = name, containerPath = "/${name}", readOnly = name == "media" }],
      logConfiguration = { logDriver = "awslogs", options = { awslogs-group = aws_cloudwatch_log_group.main.name, awslogs-region = var.aws_region, awslogs-stream-prefix = "backend" } }
    },
    {
      name             = "frontend", image = var.frontend_image, essential = true,
      portMappings     = [{ containerPort = 80, protocol = "tcp" }],
      logConfiguration = { logDriver = "awslogs", options = { awslogs-group = aws_cloudwatch_log_group.main.name, awslogs-region = var.aws_region, awslogs-stream-prefix = "frontend" } }
    }
  ])
}
resource "aws_lb" "main" {
  name               = local.name
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
  idle_timeout       = 300
}
resource "aws_lb_target_group" "main" {
  name        = local.name
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check { path = "/" }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
resource "aws_ecs_service" "main" {
  name            = local.name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  # Jellyfin has a single-writer database. Stop the old task before replacing it.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  health_check_grace_period_seconds  = 120
  network_configuration {
    subnets          = module.vpc.private_subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "frontend"
    container_port   = 80
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8096
  }
  depends_on = [aws_lb_listener.backend, aws_lb_listener.http, aws_efs_mount_target.main, aws_iam_role_policy_attachment.execution, aws_iam_role_policy.efs]
}

resource "aws_lb_target_group" "backend" {
  name        = "${local.name}-backend"
  port        = 8096
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check { path = "/health" }
}
resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8096
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
