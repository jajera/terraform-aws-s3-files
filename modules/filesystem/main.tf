resource "aws_s3files_file_system" "this" {
  bucket   = var.bucket_arn
  role_arn = var.filesystem_role_arn

  kms_key_id = var.kms_key_id
  prefix     = var.prefix

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-s3files-fs"
    }
  )
}
