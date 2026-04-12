output "filesystem_role_arn" {
  description = "ARN of the file system IAM role (null when create_filesystem_role = false)"
  value       = var.create_filesystem_role ? aws_iam_role.filesystem[0].arn : null
}

output "filesystem_role_name" {
  description = "Name of the file system IAM role (null when create_filesystem_role = false)"
  value       = var.create_filesystem_role ? aws_iam_role.filesystem[0].name : null
}

output "compute_role_arn" {
  description = "ARN of the compute IAM role (null when create_compute_role = false)"
  value       = var.create_compute_role ? aws_iam_role.compute[0].arn : null
}

output "compute_role_name" {
  description = "Name of the compute IAM role (null when create_compute_role = false)"
  value       = var.create_compute_role ? aws_iam_role.compute[0].name : null
}

output "instance_profile_arn" {
  description = "ARN of the EC2 instance profile (null when compute_type != ec2 or create_compute_role = false)"
  value       = var.create_compute_role && var.compute_type == "ec2" ? aws_iam_instance_profile.compute[0].arn : null
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile (null when compute_type != ec2 or create_compute_role = false)"
  value       = var.create_compute_role && var.compute_type == "ec2" ? aws_iam_instance_profile.compute[0].name : null
}
