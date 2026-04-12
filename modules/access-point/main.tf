resource "aws_s3files_access_point" "this" {
  file_system_id = var.file_system_id

  posix_user {
    uid = var.posix_uid
    gid = var.posix_gid
  }

  root_directory {
    path = var.root_directory

    creation_permissions {
      owner_uid   = var.posix_uid
      owner_gid   = var.posix_gid
      permissions = var.root_directory_permissions
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.access_point_name
    }
  )
}
