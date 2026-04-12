data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_arn  = "arn:aws:s3:::${var.bucket_name}"
  kms_key_arn = var.kms_key_id != null ? "arn:aws:kms:${var.aws_region}:${local.account_id}:key/${var.kms_key_id}" : null
  # Short deterministic prefix so IAM role names stay within AWS limits while matching this bucket.
  name_prefix = substr(md5(var.bucket_name), 0, 12)
}
