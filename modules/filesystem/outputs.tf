output "file_system_id" {
  description = "ID of the S3 Files file system (fs-xxxxxxxxxx)"
  value       = aws_s3files_file_system.this.id
}

output "file_system_arn" {
  description = "ARN of the S3 Files file system"
  value       = aws_s3files_file_system.this.arn
}

output "dns_name" {
  description = "File system name from the S3 Files API (mount targets expose per-AZ DNS names; mounts typically use file_system_id)"
  value       = aws_s3files_file_system.this.name
}

output "status" {
  description = "Current lifecycle status of the file system"
  value       = aws_s3files_file_system.this.status
}

output "owner_id" {
  description = "AWS account ID that owns the file system"
  value       = aws_s3files_file_system.this.owner_id
}
