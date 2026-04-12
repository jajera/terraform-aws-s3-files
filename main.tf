module "s3" {
  source = "./modules/s3"

  bucket_name   = var.bucket_name
  force_destroy = var.force_destroy
  kms_key_id    = var.kms_key_id

  tags = var.tags
}

module "iam" {
  source = "./modules/iam"

  name_prefix            = local.name_prefix
  aws_region             = var.aws_region
  account_id             = local.account_id
  bucket_arn             = module.s3.bucket_arn
  kms_key_arn            = local.kms_key_arn
  compute_type           = var.compute_type
  create_filesystem_role = var.create_filesystem_role
  create_compute_role    = var.create_compute_role

  tags = var.tags
}

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix            = local.name_prefix
  vpc_id                 = var.vpc_id
  create_ssm_endpoint_sg = var.create_ssm_endpoint_sg

  tags = var.tags
}

module "filesystem" {
  source = "./modules/filesystem"

  name_prefix         = local.name_prefix
  bucket_arn          = module.s3.bucket_arn
  filesystem_role_arn = module.iam.filesystem_role_arn
  kms_key_id          = var.kms_key_id
  prefix              = var.prefix

  tags = var.tags

  depends_on = [module.s3, module.iam]
}

module "mount_targets" {
  source = "./modules/mount-targets"

  file_system_id    = module.filesystem.file_system_id
  subnet_ids        = var.subnet_ids
  security_group_id = module.security_groups.mount_target_sg_id

  tags = var.tags

  depends_on = [module.filesystem, module.security_groups]
}

module "access_point" {
  count  = var.create_access_point ? 1 : 0
  source = "./modules/access-point"

  file_system_id             = module.filesystem.file_system_id
  access_point_name          = var.access_point_name
  posix_uid                  = var.posix_uid
  posix_gid                  = var.posix_gid
  root_directory             = var.root_directory
  root_directory_permissions = "0755"

  tags = var.tags

  depends_on = [module.filesystem]
}
