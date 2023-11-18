# ==Variables==
variable "name_prefix" {
  default = "Project with environment name."
  type    = string
}

variable "ecr_image_url" {
  description = "URL for Image inside ECR."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "ecs_task_execution_role_name" {
  description = "Name for ECS execution task role."
  type        = string
}

variable "ecs_task_role_name" {
  description = "Name for ECS task role."
  type        = string
}

variable "vpc_id" {
  description = "Id for VPC to launch in."
  type        = string
}

variable "ecs_domain" {
  description = "Domain name for this service"
  type        = string
}

variable "domain" {
  description = "Domain name for this service"
  type        = string
}

variable "logs_ttl" {
  description = "Time To Live for CloudWatch log group (in days)."
  type        = number
  default     = 14
}

variable "port" {
  description = "Port for task definition and container."
  type        = number
  default     = 8000
}

variable "tasks_count" {
  description = "Number of tasks definitions to create."
  type        = number
  default     = 0
}
# =====

# ==Locals==
locals {
  cluster_name = "${var.name_prefix}-cluster"
  service_name = "${var.name_prefix}-service"
  alb_name     = "${var.name_prefix}-alb"
}
# =====

resource "aws_cloudwatch_log_group" "MyCloudWatchLogGroup" {
  name              = "${local.cluster_name}-logs"
  retention_in_days = var.logs_ttl
}

resource "aws_ecs_cluster" "MyECSCluster" {
  name = local.cluster_name

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.MyCloudWatchLogGroup.id
      }
    }
  }
}

resource "aws_iam_role" "AmazonECSTaskExecutionRole" {
  name = "AmazonECSTaskExecutionRole"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          },
          "Effect" : "Allow",
          "Sid" : ""
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRoleAttachment" {
  policy_arn = data.aws_iam_policy.AmazonECSTaskExecutionRolePolicy.arn
  role       = aws_iam_role.AmazonECSTaskExecutionRole.name
}

resource "aws_iam_role" "MyECSTaskRole" {
  name = "MyECSTaskRole"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          },
          "Effect" : "Allow",
          "Sid" : ""
        }
      ]
    }
  )
}

resource "aws_ecs_task_definition" "MyECSTaskDefinition" {
  family                   = "${var.name_prefix}-TaskDefinition"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.AmazonECSTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.MyECSTaskRole.arn
  skip_destroy             = true
  runtime_platform {
    cpu_architecture = "X86_64"
  }
  network_mode = "awsvpc"
  container_definitions = jsonencode(
    [{
      name = "backend",
      image : var.ecr_image_url,
      portMappings = [
        { protocol = "HTTP", hostPort = var.port, containerPort = var.port }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-region        = var.aws_region,
          awslogs-group         = aws_cloudwatch_log_group.MyCloudWatchLogGroup.name,
          awslogs-stream-prefix = "backend"
        }
      },
      environment = [
        { name = "HOST", value = "0.0.0.0" },
        { name = "PORT", value = tostring(var.port) },
        { name = "DEBUG", value = "True" },
        { name = "ENABLE_OPENAPI", value = "True" },
        { name = "LOG_LEVEL", value = "10" },
        { name = "LOG_USE_COLORS", value = "False" }
      ],
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://0.0.0.0:${var.port}/ || exit 1"]
        interval    = 30
        timeout     = 3
        startPeriod = 30
        retries     = 3
      }
    }]
  )

  lifecycle {
    ignore_changes = [
      container_definitions, # comment this, to update task_definition!!!
    ]
  }
}

resource "aws_ecs_service" "MyECSService" {
  name                              = local.service_name
  cluster                           = aws_ecs_cluster.MyECSCluster.id
  task_definition                   = "${aws_ecs_task_definition.MyECSTaskDefinition.family}"
  desired_count                     = var.tasks_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 30

  load_balancer {
    container_name   = "backend"
    container_port   = var.port
    target_group_arn = aws_alb_target_group.MyALBTargetGroup.arn
  }

  network_configuration {
    subnets          = data.aws_subnets.MySubnets.ids
    assign_public_ip = true
    security_groups  = data.aws_security_groups.MySecurityGroups.ids
  }

  depends_on = [
    aws_alb_listener.MyALBListenerHTTP,
    aws_alb_listener.MyALBListenerHTTPS,
  ]
  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_alb" "MyALB" {
  load_balancer_type         = "application"
  name                       = local.alb_name
  subnets                    = data.aws_subnets.MySubnets.ids
  security_groups            = data.aws_security_groups.MySecurityGroups.ids
  enable_deletion_protection = false
  internal                   = false
  ip_address_type            = "dualstack"
  # TODO: Fix error when security groups not created yet.

  depends_on = [
    data.aws_security_groups.MySecurityGroups,
    data.aws_subnets.MySubnets,
  ]
}

resource "aws_alb_target_group" "MyALBTargetGroup" {
  name        = "${var.name_prefix}-target-group"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = var.port
  target_type = "ip"
  health_check {
    enabled             = true
    interval            = 30
    timeout             = 3
    path                = "/is_ready/"
    unhealthy_threshold = 4
    healthy_threshold   = 2
    matcher             = "200"
  }
}

resource "aws_alb_listener" "MyALBListenerHTTP" {
  load_balancer_arn = aws_alb.MyALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "MyALBListenerHTTPS" {
  load_balancer_arn = aws_alb.MyALB.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-1-2021-06"
  certificate_arn   = data.aws_acm_certificate.MyCertificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.MyALBTargetGroup.arn
  }
}

resource "aws_route53_record" "Route53ToALB" {
  name    = var.ecs_domain
  type    = "A"
  zone_id = data.aws_route53_zone.MyRoute53Zone.zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_alb.MyALB.dns_name
    zone_id                = aws_alb.MyALB.zone_id
  }
}

# ==Data==
data "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

data "aws_vpc" "MyVPC" {
  id = var.vpc_id
}

data "aws_security_groups" "MySecurityGroups" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_subnets" "MySubnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_acm_certificate" "MyCertificate" {
  domain      = "*.${var.domain}"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "MyRoute53Zone" {
  name = var.domain
}
# =====


# ==Outputs==
output "MyCertificate" {
  value = data.aws_acm_certificate.MyCertificate.id
}
# =====
