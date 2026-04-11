output "mount_target_sg_id" {
  description = "ID of the mount target security group"
  value       = aws_security_group.mount_target.id
}

output "mount_target_sg_arn" {
  description = "ARN of the mount target security group"
  value       = aws_security_group.mount_target.arn
}

output "compute_sg_id" {
  description = "ID of the compute security group"
  value       = aws_security_group.compute.id
}

output "compute_sg_arn" {
  description = "ARN of the compute security group"
  value       = aws_security_group.compute.arn
}

output "ssm_endpoint_sg_id" {
  description = "ID of the SSM endpoint security group (null when create_ssm_endpoint_sg = false)"
  value       = var.create_ssm_endpoint_sg ? aws_security_group.ssm_endpoint[0].id : null
}
