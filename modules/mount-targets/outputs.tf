output "mount_target_ids" {
  description = "Map of subnet ID to mount target ID"
  value       = { for subnet_id, mt in aws_s3files_mount_target.this : subnet_id => mt.id }
}

output "mount_target_network_interface_ids" {
  description = "Map of subnet ID to the mount target's elastic network interface ID"
  value       = { for subnet_id, mt in aws_s3files_mount_target.this : subnet_id => mt.network_interface_id }
}

output "mount_target_ipv4_addresses" {
  description = "Map of subnet ID to the mount target's IPv4 address (aws_s3files_mount_target does not expose dns_name in the Terraform AWS provider)"
  value       = { for subnet_id, mt in aws_s3files_mount_target.this : subnet_id => mt.ipv4_address }
}
