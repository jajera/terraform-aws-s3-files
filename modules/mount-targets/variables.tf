variable "file_system_id" {
  description = "ID of the S3 Files file system to attach mount targets to"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs in which to create mount targets (one per AZ recommended)"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the security group to attach to mount targets (must allow NFS TCP 2049 inbound from compute)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to mount targets"
  type        = map(string)
  default     = {}
}
