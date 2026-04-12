variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "vpc_id" {
  description = "ID of the VPC where mount targets and security groups are created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs in which to create mount targets (one per AZ recommended)"
  type        = list(string)
}

variable "bucket_name" {
  description = "Name of the S3 bucket to back the file system. Must be globally unique. S3 Files requires versioning — it will be enabled automatically."
  type        = string
}

variable "compute_type" {
  description = "Compute platform that will mount the file system. Selects the IAM trust principal for the compute role."
  type        = string
  default     = "ec2"

  validation {
    condition     = contains(["ec2", "ecs", "eks", "lambda"], var.compute_type)
    error_message = "compute_type must be one of: ec2, ecs, eks, lambda."
  }
}

variable "create_filesystem_role" {
  description = "If true, create the IAM role assumed by elasticfilesystem.amazonaws.com for S3 sync"
  type        = bool
  default     = true
}

variable "create_compute_role" {
  description = "If true, create the IAM role for the compute platform to mount the file system"
  type        = bool
  default     = true
}

variable "create_access_point" {
  description = "If true, create an S3 Files access point. Required for Lambda mounts."
  type        = bool
  default     = false
}

variable "create_ssm_endpoint_sg" {
  description = "If true, create a security group for the SSM VPC interface endpoint (HTTPS 443 inbound from compute SG)"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID or ARN for SSE-KMS encryption. If null, SSE-S3 (AES256) is used. S3 Files does not support SSE-C."
  type        = string
  default     = null
}

variable "prefix" {
  description = "S3 key prefix to scope the file system to a subdirectory of the bucket. If null, the root of the bucket is used."
  type        = string
  default     = null
}

variable "access_point_name" {
  description = "Logical label for the access point (used for the Name tag when create_access_point = true; the AWS-assigned access point name is returned in outputs)"
  type        = string
  default     = "default"
}

variable "posix_uid" {
  description = "POSIX user ID for the access point (used when create_access_point = true)"
  type        = number
  default     = 1000
}

variable "posix_gid" {
  description = "POSIX group ID for the access point (used when create_access_point = true)"
  type        = number
  default     = 1000
}

variable "root_directory" {
  description = "Root directory path for the access point (used when create_access_point = true)"
  type        = string
  default     = "/"
}

variable "force_destroy" {
  description = "If true, allow Terraform to destroy the S3 bucket even when it contains objects"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}
