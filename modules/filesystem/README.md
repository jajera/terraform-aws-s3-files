# module: filesystem

Creates an Amazon S3 Files file system (`aws_s3files_file_system`) linked to an S3 bucket.

**Prerequisites:**

- Bucket versioning must be enabled (handled by the `s3` module)
- File system IAM role must exist before apply (handled by the `iam` module)
- Requires AWS provider >= 6.40

The file system transitions through `Creating` → `available`. If it becomes stuck in `Creating` with `statusMessage: "Access denied: ... s3:HeadObject"`, the IAM role policy points to the wrong bucket — update the policy and the file system retries automatically within ~60 seconds.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
