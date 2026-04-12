output "access_point_id" {
  description = "ID of the S3 Files access point"
  value       = aws_s3files_access_point.this.id
}

output "access_point_arn" {
  description = "ARN of the S3 Files access point (used in Lambda file system config)"
  value       = aws_s3files_access_point.this.arn
}

output "access_point_name" {
  description = "Name of the S3 Files access point"
  value       = aws_s3files_access_point.this.name
}
