# module: s3

Creates an S3 bucket pre-configured for use with Amazon S3 Files:

- Versioning always enabled (required by S3 Files)
- SSE-S3 (AES256) by default; SSE-KMS when `kms_key_id` is provided
- All public access blocked
- Object ownership enforced (no ACLs)

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
