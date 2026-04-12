variable "name_prefix" {
  description = "Prefix for IAM resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region (used in IAM trust policy ARN conditions)"
  type        = string
}

variable "account_id" {
  description = "AWS account ID (used in IAM trust policy conditions)"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket that backs the file system"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for bucket encryption. When null, the KMS statement is omitted from the filesystem role policy."
  type        = string
  default     = null
}

variable "compute_type" {
  description = "Compute platform for the client role trust policy. One of: ec2, ecs, eks, lambda."
  type        = string
  default     = "ec2"

  validation {
    condition     = contains(["ec2", "ecs", "eks", "lambda"], var.compute_type)
    error_message = "compute_type must be one of: ec2, ecs, eks, lambda."
  }
}

variable "create_filesystem_role" {
  description = "Create the IAM role assumed by elasticfilesystem.amazonaws.com"
  type        = bool
  default     = true
}

variable "create_compute_role" {
  description = "Create the IAM role for the compute platform"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
