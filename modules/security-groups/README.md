# module: security-groups

Creates the security groups and rules for S3 Files NFS traffic.

Two security groups are always created:

| Group | Purpose |
|-------|---------|
| `{name_prefix}-s3files-mt-sg` | Attached to mount targets. Allows NFS TCP 2049 inbound from the compute SG. |
| `{name_prefix}-s3files-compute-sg` | Attached to compute resources. Allows NFS TCP 2049 outbound to the mount target SG. |

Security groups are declared without inline rules, and `aws_security_group_rule` resources are used separately. This avoids the circular dependency that would arise if both groups referenced each other inline.

An optional SSM endpoint SG is created when `create_ssm_endpoint_sg = true`, allowing the `ssm` VPC interface endpoint to accept HTTPS from the compute SG.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
