variable "bucket_name" {
  description = "Name of the S3 bucket (globally unique). S3 Files requires versioning — it is always enabled."
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even when it is non-empty"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID or ARN for SSE-KMS. When null, SSE-S3 (AES256) is used. S3 Files does not support SSE-C."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
