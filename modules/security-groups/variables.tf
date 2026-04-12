variable "name_prefix" {
  description = "Prefix for security group names"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where security groups are created"
  type        = string
}

variable "create_ssm_endpoint_sg" {
  description = "If true, create a security group for the SSM VPC interface endpoint (HTTPS 443 inbound from compute SG)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
