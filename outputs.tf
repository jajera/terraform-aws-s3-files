#
# Naming
#
output "name_prefix" {
  description = "Derived prefix used for IAM roles, security groups, and tags (stable for a given bucket_name)"
  value       = local.name_prefix
}

#
# S3 bucket outputs
#
output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = module.s3.bucket_id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.bucket_arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = module.s3.bucket_regional_domain_name
}

#
# IAM outputs
#
output "filesystem_role_arn" {
  description = "ARN of the S3 Files file system IAM role"
  value       = module.iam.filesystem_role_arn
}

output "filesystem_role_name" {
  description = "Name of the S3 Files file system IAM role"
  value       = module.iam.filesystem_role_name
}

output "compute_role_arn" {
  description = "ARN of the compute IAM role"
  value       = module.iam.compute_role_arn
}

output "compute_role_name" {
  description = "Name of the compute IAM role"
  value       = module.iam.compute_role_name
}

output "instance_profile_arn" {
  description = "ARN of the EC2 instance profile (only set when compute_type = ec2)"
  value       = module.iam.instance_profile_arn
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile (only set when compute_type = ec2)"
  value       = module.iam.instance_profile_name
}

#
# Security group outputs
#
output "mount_target_sg_id" {
  description = "ID of the mount target security group"
  value       = module.security_groups.mount_target_sg_id
}

output "compute_sg_id" {
  description = "ID of the compute security group"
  value       = module.security_groups.compute_sg_id
}

output "ssm_endpoint_sg_id" {
  description = "ID of the SSM endpoint security group (null when create_ssm_endpoint_sg = false)"
  value       = module.security_groups.ssm_endpoint_sg_id
}

#
# File system outputs
#
output "file_system_id" {
  description = "ID of the S3 Files file system"
  value       = module.filesystem.file_system_id
}

output "file_system_arn" {
  description = "ARN of the S3 Files file system"
  value       = module.filesystem.file_system_arn
}

output "file_system_dns_name" {
  description = "File system name from the S3 Files API (use mount target DNS names or file_system_id for mounts per AWS documentation)"
  value       = module.filesystem.dns_name
}

#
# Mount target outputs
#
output "mount_target_ids" {
  description = "Map of subnet ID to mount target ID"
  value       = module.mount_targets.mount_target_ids
}

#
# Access point outputs
#
output "access_point_arn" {
  description = "ARN of the S3 Files access point (null when create_access_point = false)"
  value       = var.create_access_point ? module.access_point[0].access_point_arn : null
}

output "access_point_id" {
  description = "ID of the S3 Files access point (null when create_access_point = false)"
  value       = var.create_access_point ? module.access_point[0].access_point_id : null
}
