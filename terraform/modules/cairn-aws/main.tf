# Cairn on AWS — ECS Fargate behind an ALB.
#
# Layout:
#   - one ECS cluster (Fargate-only)
#   - one Service running cairn-serve, with an init container that
#     downloads the bundle tar.gz on every task start
#   - ALB target group on /healthz; ALB listener on :80 + optional :443
#   - CloudWatch log group with configurable retention
#   - SecurityGroups: ALB allows 80/443 from the world (or VPC if
#     internal); tasks only accept traffic from the ALB SG
#   - App Auto Scaling on CPU 70% (min/max from variables)
#
# Bundle distribution: fetched on task start from `bundle_url`. Use
# CloudFront-fronted S3 in production so the URL is cheap to hit. The
# Helm chart's signature-verify init container is omitted here because
# Fargate task definitions don't trivially compose multi-image init
# stages without a shared volume — adopt EFS or run cairn-build inside
# the bundle URL pipeline if signed bundles matter to you.

locals {
  port = 8080
  tags = var.tags
}

# ── ECS cluster ─────────────────────────────────────────────────────
resource "aws_ecs_cluster" "this" {
  name = var.name
  tags = local.tags

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

# ── Security groups ────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Cairn ALB ingress"
  vpc_id      = var.vpc_id
  tags        = local.tags

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.internal_alb ? [data.aws_vpc.this.cidr_block] : ["0.0.0.0/0"]
  }

  egress {
    description = "to tasks"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks"
  description = "Cairn ECS tasks"
  vpc_id      = var.vpc_id
  tags        = local.tags

  ingress {
    description     = "from alb"
    from_port       = local.port
    to_port         = local.port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "to internet (bundle fetch + image pull)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

# ── ALB ────────────────────────────────────────────────────────────
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = var.internal_alb
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
  tags               = local.tags
}

resource "aws_lb_target_group" "this" {
  name_prefix          = "cairn-" # 6-char limit; keep short.
  port                 = local.port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 15
  tags                 = local.tags

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 3
    matcher             = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# ── IAM for the task ───────────────────────────────────────────────
data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "exec" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = local.tags
}

# ── Task definition ─────────────────────────────────────────────────
locals {
  bundle_path = "/bundle"
  fetch_cmd = trimspace(<<-EOT
    set -eu
    cd /tmp
    curl -fSL --retry 3 -o bundle.tar.gz "${var.bundle_url}"
    %{if var.bundle_sha256 != ""}
    echo "${var.bundle_sha256}  bundle.tar.gz" | sha256sum -c -
    %{endif}
    mkdir -p ${local.bundle_path}
    tar -C ${local.bundle_path} --strip-components=1 -xzf bundle.tar.gz
    rm -f bundle.tar.gz
  EOT
  )
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn
  tags                     = local.tags

  volume {
    name = "bundle"
  }

  container_definitions = jsonencode([
    {
      name      = "bundle-fetch"
      image     = "alpine/curl:8"
      essential = false
      command   = ["/bin/sh", "-c", local.fetch_cmd]
      mountPoints = [
        {
          sourceVolume  = "bundle"
          containerPath = local.bundle_path
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "fetch"
        }
      }
    },
    {
      name      = "cairn"
      image     = var.image
      essential = true
      dependsOn = [
        {
          containerName = "bundle-fetch"
          condition     = "SUCCESS"
        }
      ]
      portMappings = [
        {
          containerPort = local.port
          protocol      = "tcp"
        }
      ]
      command = [
        "--bundle", local.bundle_path,
        "--bind", "0.0.0.0:${local.port}",
      ]
      mountPoints = [
        {
          sourceVolume  = "bundle"
          containerPath = local.bundle_path
          readOnly      = true
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "serve"
        }
      }
      readonlyRootFilesystem = true
      user                   = "65532:65532"
    }
  ])
}

data "aws_region" "current" {}

# ── ECS service ────────────────────────────────────────────────────
resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = aws_ecs_cluster.this.arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "cairn"
    container_port   = local.port
  }

  depends_on = [aws_lb_listener.http]
  tags       = local.tags

  lifecycle {
    ignore_changes = [desired_count] # autoscaling owns this once active
  }
}

# ── App Auto Scaling on CPU ────────────────────────────────────────
resource "aws_appautoscaling_target" "this" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
