terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.40"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
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
  description = "Subnet IDs for mount targets and Lambda"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet_id is required."
  }
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
  name_prefix = substr(md5(local.bucket_name), 0, 12)
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

# Lambda requires an access point — it cannot mount by file system ID alone.
module "s3_files" {
  source = "../../"

  aws_region    = var.aws_region
  vpc_id        = var.vpc_id
  subnet_ids    = var.subnet_ids
  bucket_name   = local.bucket_name
  force_destroy = var.bucket_force_destroy

  compute_type = "lambda"

  create_access_point = true
  access_point_name   = "${local.name_prefix}-lambda-ap"
  posix_uid           = 1000
  posix_gid           = 1000
  root_directory      = "/lambda"

  tags = var.tags
}

# VPC-attached Lambda ENIs need DNS and HTTPS (same pattern as examples/ec2).
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
  description       = "HTTPS (AWS APIs from ENI when subnets use a NAT gateway)"
  security_group_id = module.s3_files.compute_sg_id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${module.s3_files.name_prefix}-s3files"
  retention_in_days = var.log_retention_days

  tags = var.tags

  depends_on = [module.s3_files]
}

# Inline Lambda function that lists the mounted file system root
data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"

  source {
    content  = <<-PYTHON
      import os

      def handler(event, context):
          path = '/mnt/s3files'
          entries = os.listdir(path)
          print(f"Contents of {path}: {entries}")
          return {'statusCode': 200, 'body': str(entries)}
    PYTHON
    filename = "index.py"
  }
}

resource "aws_lambda_function" "this" {
  function_name    = "${module.s3_files.name_prefix}-s3files"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.14"
  role             = module.s3_files.compute_role_arn
  timeout          = 30

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [module.s3_files.compute_sg_id]
  }

  file_system_config {
    arn              = module.s3_files.access_point_arn
    local_mount_path = "/mnt/s3files"
  }

  environment {
    variables = {
      FILE_SYSTEM_ID = module.s3_files.file_system_id
    }
  }

  depends_on = [
    module.s3_files,
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy.lambda_logs,
  ]

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = module.s3_files.compute_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"

  depends_on = [module.s3_files]
}

# Allow Lambda to write CloudWatch logs
resource "aws_iam_role_policy" "lambda_logs" {
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

  depends_on = [module.s3_files]
}

output "aws_region" {
  description = "AWS region used for this deployment"
  value       = var.aws_region
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "file_system_id" {
  description = "ID of the S3 Files file system"
  value       = module.s3_files.file_system_id
}

output "access_point_arn" {
  description = "ARN of the S3 Files access point"
  value       = module.s3_files.access_point_arn
}

output "bucket_name" {
  description = "Name of the S3 bucket backing the file system"
  value       = module.s3_files.bucket_id
}
