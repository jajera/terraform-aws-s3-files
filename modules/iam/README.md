# module: iam

Creates the two IAM roles required by Amazon S3 Files:

| Role | Service principal | Purpose |
|------|-------------------|---------|
| File system role | `elasticfilesystem.amazonaws.com` | S3 Files reads/writes the S3 bucket and manages EventBridge sync rules |
| Compute role | Varies by `compute_type` | Compute mounts the file system and reads objects directly |

Both roles are independently toggled via `create_filesystem_role` and `create_compute_role`.

The file system role trust policy follows [AWS S3 Files prerequisites](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-prereq-policies.html): `aws:SourceArn` uses `arn:aws:s3files:…:file-system/*` (not `elasticfilesystem` in the ARN). EventBridge statements use the `DO-NOT-DELETE-S3-Files*` rule prefix and `events:ManagedBy` where required — mismatches here often surface as console **Unknown Error** on the synchronization page.

The `compute_type` variable selects the trust principal:

| Value | Principal |
|-------|-----------|
| `ec2` | `ec2.amazonaws.com` + creates instance profile |
| `ecs` | `ecs-tasks.amazonaws.com` |
| `eks` | `pods.eks.amazonaws.com` |
| `lambda` | `lambda.amazonaws.com` |

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
