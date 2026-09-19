terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.41" # s3files_volume_configuration on aws_ecs_task_definition
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-6"
}

variable "bucket_name" {
  description = "S3 bucket name. If null, a name is generated with a random suffix (s3files-demo-<suffix>)."
  type        = string
  default     = null
}

variable "bucket_force_destroy" {
  description = "If true, allow Terraform to destroy the S3 bucket even when it contains objects (recommended for throwaway demos)"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for mount targets, the container instance, and ECS task ENIs"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet_id is required."
  }
}

variable "instance_subnet_id" {
  description = "Subnet for the ECS container instance (defaults to the first subnet_ids entry)"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type for the ECS container instance"
  type        = string
  default     = "t3.small"
}

variable "container_image" {
  description = "Container image to run (must be compatible with Amazon Linux)"
  type        = string
  default     = "public.ecr.aws/amazonlinux/amazonlinux:2023"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

resource "random_id" "bucket_suffix" {
  count       = var.bucket_name == null ? 1 : 0
  byte_length = 4
}

locals {
  bucket_name        = var.bucket_name != null ? var.bucket_name : "s3files-demo-${random_id.bucket_suffix[0].hex}"
  instance_subnet_id = coalesce(var.instance_subnet_id, var.subnet_ids[0])
  cluster_name       = "${module.s3_files.name_prefix}-s3files-ec2"
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

# Recommended ECS-optimized AL2023 AMI (agent >= 1.104 required for ecs.capability.storage.s3-files).
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

module "s3_files" {
  source = "../../"

  aws_region    = var.aws_region
  vpc_id        = var.vpc_id
  subnet_ids    = var.subnet_ids
  bucket_name   = local.bucket_name
  force_destroy = var.bucket_force_destroy

  compute_type = "ecs"

  tags = var.tags
}

resource "aws_security_group_rule" "compute_egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  description       = "DNS to VPC resolver"
  security_group_id = module.s3_files.compute_sg_id
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
}

resource "aws_security_group_rule" "compute_egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  description       = "DNS to VPC resolver (TCP fallback)"
  security_group_id = module.s3_files.compute_sg_id
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
}

resource "aws_security_group_rule" "compute_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  description       = "HTTPS (ECS agent, CloudWatch Logs, ECR, etc.)"
  security_group_id = module.s3_files.compute_sg_id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  tags = var.tags
}

# Container instance role (distinct from the ECS task role created by the module).
resource "aws_iam_role" "ecs_instance" {
  name = "${module.s3_files.name_prefix}-s3files-ecs-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags

  depends_on = [module.s3_files]
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${module.s3_files.name_prefix}-s3files-ecs-instance"
  role = aws_iam_role.ecs_instance.name

  tags = var.tags
}

resource "aws_instance" "ecs" {
  ami                    = data.aws_ssm_parameter.ecs_ami.value
  instance_type          = var.instance_type
  subnet_id              = local.instance_subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ecs_instance.name
  vpc_security_group_ids = [module.s3_files.compute_sg_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = <<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.this.name}" >> /etc/ecs/ecs.config
  EOF

  tags = merge(var.tags, {
    Name = "${module.s3_files.name_prefix}-s3files-ecs-instance"
  })

  depends_on = [
    aws_ecs_cluster.this,
    aws_iam_role_policy_attachment.ecs_instance,
  ]
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${module.s3_files.name_prefix}-s3files-ec2"
  retention_in_days = var.log_retention_days

  tags = var.tags

  depends_on = [module.s3_files]
}

resource "aws_iam_role_policy" "ecs_task_logs" {
  name = "CloudWatchLogsPolicy"
  role = module.s3_files.compute_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.this.arn}:*"
      }
    ]
  })

  depends_on = [module.s3_files, aws_cloudwatch_log_group.this]
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = module.s3_files.compute_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

  depends_on = [module.s3_files]
}

# Native volume.s3files_volume_configuration (AWS provider >= 6.41). Use the file system ARN
# from Terraform — do not synthesize an arn:aws:elasticfilesystem:... string.
resource "aws_ecs_task_definition" "this" {
  family                   = "${module.s3_files.name_prefix}-s3files-ec2"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = module.s3_files.compute_role_arn
  task_role_arn            = module.s3_files.compute_role_arn

  container_definitions = jsonencode([
    {
      name      = "s3files-demo"
      image     = var.container_image
      essential = true
      memory    = 512
      mountPoints = [
        {
          sourceVolume  = "s3files"
          containerPath = "/mnt/s3files"
          readOnly      = false
        }
      ]
      command = [
        "sh",
        "-c",
        "set -e; echo ====S3Files-df====; df -h /mnt/s3files || true; echo ====listing====; ls -la /mnt/s3files; echo written-at-$(date -u +%Y-%m-%dT%H:%M:%SZ)-ec2-demo > /mnt/s3files/ecs-s3files-demo.txt; echo ====read-back====; cat /mnt/s3files/ecs-s3files-demo.txt; echo ====done====; sleep 3600"
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "s3files"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "test -f /mnt/s3files/ecs-s3files-demo.txt && grep -q ec2-demo /mnt/s3files/ecs-s3files-demo.txt || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 90
      }
    }
  ])

  volume {
    name = "s3files"

    s3files_volume_configuration {
      file_system_arn = module.s3_files.file_system_arn
      root_directory  = "/"
    }
  }

  tags = var.tags

  depends_on = [
    module.s3_files,
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.ecs_task_logs,
    aws_iam_role_policy_attachment.ecs_task_execution,
  ]
}

resource "aws_ecs_service" "this" {
  name            = "${module.s3_files.name_prefix}-s3files-ec2"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [module.s3_files.compute_sg_id]
  }

  tags = var.tags

  depends_on = [
    aws_instance.ecs,
    aws_ecs_task_definition.this,
    aws_iam_role_policy.ecs_task_logs,
    aws_iam_role_policy_attachment.ecs_task_execution,
  ]
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster created by this example"
  value       = aws_ecs_cluster.this.name
}

output "ecs_instance_id" {
  description = "ID of the ECS container instance"
  value       = aws_instance.ecs.id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "file_system_id" {
  description = "ID of the S3 Files file system"
  value       = module.s3_files.file_system_id
}

output "task_definition_family" {
  description = "ECS task definition family"
  value       = aws_ecs_task_definition.this.family
}

output "log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.this.name
}

output "bucket_name" {
  description = "Name of the S3 bucket backing the file system"
  value       = module.s3_files.bucket_id
}
