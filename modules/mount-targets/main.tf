# One mount target per subnet. Use for_each so each mount target has its own
# lifecycle and can be updated independently.
resource "aws_s3files_mount_target" "this" {
  for_each = toset(var.subnet_ids)

  file_system_id  = var.file_system_id
  subnet_id       = each.value
  security_groups = [var.security_group_id]
}
