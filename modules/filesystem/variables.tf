variable "name_prefix" {
  description = "Prefix used in the Name tag"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket that backs the file system (versioning must already be enabled)"
  type        = string
}

variable "filesystem_role_arn" {
  description = "ARN of the IAM role assumed by elasticfilesystem.amazonaws.com for S3 sync"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for SSE-KMS encryption. When null, SSE-S3 is used."
  type        = string
  default     = null
}

variable "prefix" {
  description = "S3 key prefix to scope the file system. When null, the entire bucket is accessible."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
