terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.40"
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
  default     = "ap-southeast-2"
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
  description = "Subnet IDs for mount targets and ECS tasks"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet_id is required."
  }
}

variable "ecs_cluster_name" {
  description = "Name of the existing ECS cluster to deploy into"
  type        = string
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
  bucket_name = var.bucket_name != null ? var.bucket_name : "s3files-demo-${random_id.bucket_suffix[0].hex}"
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
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
  description       = "HTTPS (CloudWatch Logs, ECR, etc.)"
  security_group_id = module.s3_files.compute_sg_id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${module.s3_files.name_prefix}-s3files"
  retention_in_days = var.log_retention_days

  tags = var.tags

  depends_on = [module.s3_files]
}

resource "aws_iam_role_policy" "ecs_task_logs" {
  name = "CloudWatchLogsPolicy"
  role = split("/", module.s3_files.compute_role_arn)[1]

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

# aws_ecs_task_definition does not yet support s3filesVolumeConfiguration natively.
# The task definition is registered via local-exec using the AWS CLI.
# Use the file system ARN from Terraform (aws_s3files_file_system.arn) — do not synthesize an
# arn:aws:elasticfilesystem:... string; S3 Files ARNs use the s3files service namespace.
resource "terraform_data" "task_definition" {
  input = {
    region          = var.aws_region
    family          = "${module.s3_files.name_prefix}-s3files"
    execution_role  = module.s3_files.compute_role_arn
    task_role       = module.s3_files.compute_role_arn
    file_system_arn = module.s3_files.file_system_arn
    log_group       = aws_cloudwatch_log_group.this.name
    image           = var.container_image
  }

  provisioner "local-exec" {
    # --container-definitions is wrapped in single quotes for the shell; do not use "'" inside that JSON
    # (e.g. in the container command) or /bin/sh will truncate the string and aws cli will fail.
    command = <<-EOT
      aws ecs register-task-definition \
        --region "${self.input.region}" \
        --family "${self.input.family}" \
        --network-mode awsvpc \
        --requires-compatibilities FARGATE \
        --cpu 256 \
        --memory 512 \
        --execution-role-arn "${self.input.execution_role}" \
        --task-role-arn "${self.input.task_role}" \
        --container-definitions '[
          {
            "name": "s3files-demo",
            "image": "${self.input.image}",
            "essential": true,
            "mountPoints": [{"sourceVolume":"s3files","containerPath":"/mnt/s3files","readOnly":false}],
            "command": ["sh","-c","set -e; echo ====S3Files-df====; df -h /mnt/s3files || true; echo ====listing====; ls -la /mnt/s3files; echo written-at-$(date -u +%Y-%m-%dT%H:%M:%SZ)-fargate-demo > /mnt/s3files/ecs-s3files-demo.txt; echo ====read-back====; cat /mnt/s3files/ecs-s3files-demo.txt; echo ====done====; sleep 3600"],
            "logConfiguration": {
              "logDriver": "awslogs",
              "options": {
                "awslogs-group": "${self.input.log_group}",
                "awslogs-region": "${self.input.region}",
                "awslogs-stream-prefix": "s3files"
              }
            },
            "healthCheck": {
              "command": ["CMD-SHELL", "test -f /mnt/s3files/ecs-s3files-demo.txt && grep -q fargate-demo /mnt/s3files/ecs-s3files-demo.txt || exit 1"],
              "interval": 30,
              "timeout": 5,
              "retries": 3,
              "startPeriod": 90
            }
          }
        ]' \
        --volumes '[
          {
            "name": "s3files",
            "s3filesVolumeConfiguration": {
              "fileSystemArn": "${self.input.file_system_arn}",
              "rootDirectory": "/"
            }
          }
        ]'
    EOT
  }

  depends_on = [
    module.s3_files,
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.ecs_task_logs,
    aws_iam_role_policy_attachment.ecs_task_execution,
  ]
}

# ECS service runs the task on the existing Fargate cluster.
# The task definition ARN is resolved after local-exec registers it.
data "aws_ecs_task_definition" "this" {
  task_definition = "${module.s3_files.name_prefix}-s3files"

  depends_on = [terraform_data.task_definition]
}

resource "aws_ecs_service" "this" {
  name            = "${module.s3_files.name_prefix}-s3files"
  cluster         = data.aws_ecs_cluster.this.arn
  task_definition = data.aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [module.s3_files.compute_sg_id]
    assign_public_ip = false
  }

  tags = var.tags

  depends_on = [
    terraform_data.task_definition,
    aws_iam_role_policy.ecs_task_logs,
    aws_iam_role_policy_attachment.ecs_task_execution,
  ]
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
  value       = "${module.s3_files.name_prefix}-s3files"
}

output "log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.this.name
}

output "bucket_name" {
  description = "Name of the S3 bucket backing the file system"
  value       = module.s3_files.bucket_id
}
