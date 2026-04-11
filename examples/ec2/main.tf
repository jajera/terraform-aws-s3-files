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
  description = "Subnet IDs for mount targets"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet_id is required."
  }
}

variable "instance_subnet_id" {
  description = "Subnet ID for the EC2 instance (defaults to the first mount target subnet)"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
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
}

# Needed so the instance can resolve ssm.*.amazonaws.com (compute SG otherwise only allows NFS + 443).
data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "s3_files" {
  source = "../../"

  aws_region    = var.aws_region
  vpc_id        = var.vpc_id
  subnet_ids    = var.subnet_ids
  bucket_name   = local.bucket_name
  force_destroy = var.bucket_force_destroy

  compute_type = "ec2"

  tags = var.tags
}

# DNS to the VPC resolver (AmazonProvidedDNS at VPC_NETWORK+2). Without this, SSM stays "offline"
# because the agent cannot resolve AWS API hostnames.
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

# HTTPS egress for SSM and dnf (no VPC interface endpoints in this example).
resource "aws_security_group_rule" "compute_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  description       = "HTTPS (SSM, package repos)"
  security_group_id = module.s3_files.compute_sg_id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = module.s3_files.compute_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

  depends_on = [module.s3_files]
}

# EC2 instance with the S3 Files compute role attached via instance profile.
# User data installs amazon-efs-utils (v3+) and mounts the file system.
resource "aws_instance" "this" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = var.instance_type
  subnet_id            = local.instance_subnet_id
  iam_instance_profile = module.s3_files.instance_profile_name

  vpc_security_group_ids = [module.s3_files.compute_sg_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    dnf install -y amazon-efs-utils amazon-ssm-agent

    systemctl enable amazon-ssm-agent --now

    mkdir -p /mnt/s3files
    mount -t s3files ${module.s3_files.file_system_id}:/ /mnt/s3files

    # Default root is often root-only; ec2-user must be able to list without sudo.
    chmod 755 /mnt/s3files
    chown ec2-user:ec2-user /mnt/s3files || true

    echo "${module.s3_files.file_system_id}:/ /mnt/s3files s3files _netdev,noresvport 0 0" >> /etc/fstab

    cat >/etc/systemd/system/s3files-mount-perms.service <<'EOFSVC'
[Unit]
Description=Allow ec2-user to access S3 Files mount root
RequiresMountsFor=/mnt/s3files
After=mnt-s3files.mount

[Service]
Type=oneshot
ExecStart=/bin/sh -c '/bin/chmod 755 /mnt/s3files && /bin/chown ec2-user:ec2-user /mnt/s3files || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOFSVC
    systemctl daemon-reload
    systemctl enable s3files-mount-perms.service

    echo "S3 Files mounted at /mnt/s3files"
  EOF

  tags = merge(
    var.tags,
    {
      Name = "${module.s3_files.name_prefix}-s3files-ec2"
    }
  )

  depends_on = [
    module.s3_files,
    aws_iam_role_policy_attachment.ssm_managed_instance,
  ]
}

output "aws_region" {
  description = "AWS region used for this deployment"
  value       = var.aws_region
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "file_system_id" {
  description = "ID of the S3 Files file system"
  value       = module.s3_files.file_system_id
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3_files.bucket_id
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI used for the instance"
  value       = data.aws_ami.al2023.id
}
