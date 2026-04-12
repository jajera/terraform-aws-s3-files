variable "file_system_id" {
  description = "ID of the S3 Files file system to create the access point on"
  type        = string
}

variable "access_point_name" {
  description = "Name tag for the access point (provider assigns the resource name)"
  type        = string
  default     = "default"
}

variable "posix_uid" {
  description = "POSIX user ID enforced by the access point"
  type        = number
  default     = 1000
}

variable "posix_gid" {
  description = "POSIX group ID enforced by the access point"
  type        = number
  default     = 1000
}

variable "root_directory" {
  description = "Root directory path exposed by the access point. Lambda mounts this path as /."
  type        = string
  default     = "/"
}

variable "root_directory_permissions" {
  description = "POSIX permissions (octal string) applied when creating the root directory"
  type        = string
  default     = "0755"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
