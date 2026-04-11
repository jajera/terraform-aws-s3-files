# Agent Context

Terraform module for **Amazon S3 Files** — provisions an NFS-compatible file system interface backed by an S3 bucket, mountable on EC2, ECS Fargate, EKS, and Lambda.

## What this repo is

`terraform-aws-s3-files` is a reusable Terraform root module and collection of submodules that automate the AWS CLI walkthrough documented at [s3-files-workloads](https://jajera.github.io/s3-files-workloads/). Use it alongside that site for context on why each resource exists and what errors to expect during provisioning.

## Provider requirements

- **AWS provider:** `>= 6.40` — minimum version that includes native `aws_s3files_*` resources
- **Terraform:** `>= 1.5.0`

## Default region

Always use `ap-southeast-2` in all examples and default variable values. The user has existing ECS and EKS clusters in this region.

## Module structure

```plaintext
modules/
  s3/              S3 bucket (versioning + SSE required by S3 Files)
  iam/             File system role + per-compute-type client role
  filesystem/      aws_s3files_file_system
  mount-targets/   aws_s3files_mount_target (one per subnet, for_each)
  security-groups/ NFS port 2049 rules (no inline rules, use aws_security_group_rule)
  access-point/    aws_s3files_access_point (required for Lambda)

examples/
  ec2/     EC2 instance with amazon-efs-utils mount
  ecs/     ECS Fargate on existing cluster (terraform_data + local-exec for task def)
  eks/     EKS PV/PVC via EFS CSI driver on existing cluster
  lambda/  Lambda with access point
```

## Key S3 Files facts

### Two IAM roles — always create both

| Role             | Service principal                 | Purpose                                          |
|------            |-------------------                |---------                                         |
| File system role | `elasticfilesystem.amazonaws.com` | Reads/writes S3 bucket, manages EventBridge sync |
| Compute role     | Varies by compute type            | Mounts file system, reads objects directly       |

The `iam` module creates both roles. Use `create_filesystem_role` and `create_compute_role` feature flags.

### File system role trust policy (common mistake)

The assume-role **principal** is `elasticfilesystem.amazonaws.com`, but the trust policy **`aws:SourceArn` condition must use the S3 Files resource namespace**, not EFS:

- Correct: `arn:aws:s3files:REGION:ACCOUNT_ID:file-system/*`
- Wrong: `arn:aws:elasticfilesystem:REGION:ACCOUNT_ID:file-system/*`

If `SourceArn` is wrong, `create-file-system` can fail or the console **Synchronization configuration** panel can show **Unknown Error** while the API returns permission errors for EventBridge sync rules.

EventBridge inline policy must target rules named `DO-NOT-DELETE-S3-Files*` with `events:ManagedBy = elasticfilesystem.amazonaws.com` on manage actions, per [AWS prerequisites for S3 Files](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-prereq-policies.html).

### Bucket prerequisites

- **Versioning must be enabled** — `modules/s3` always enables it
- **Only SSE-S3 or SSE-KMS** — SSE-C is not supported; set `kms_key_id` to use KMS

### Per-platform constraints

| Platform | Constraint                                                             |
| -------- |-----------                                                             |
| EC2      | Requires `amazon-efs-utils` v3.0.0+; mount type `-t s3files`           |
| EKS      | Uses Amazon EFS CSI driver (`aws-efs-csi-driver`) — same driver as EFS |
| ECS      | **Fargate and Managed Instances only** — EC2 launch type not supported |
| Lambda   | **Access point required** — cannot mount by file system ID alone       |

### ECS task definition limitation

`aws_ecs_task_definition` does not yet support `s3filesVolumeConfiguration`. The `examples/ecs` example uses `terraform_data` + `local-exec` to call `aws ecs register-task-definition` directly. Requires AWS CLI v2.34.26+ on the machine running `terraform apply`.

### Security group port

NFS port **2049 TCP** between compute SG and mount target SG. Always use `aws_security_group_rule` resources — never inline rules — to avoid circular dependencies.

## Naming convention

`${var.name_prefix}-<resource>-<type>` — all lowercase, hyphens only.

Examples:

- `demo-s3files-filesystem-role`
- `demo-s3files-mt-sg`
- `demo-s3files-compute-sg`
- `demo-s3files-ecs-role`

## Companion documentation

- CLI walkthrough: <https://jajera.github.io/s3-files-workloads/>
- AWS S3 Files docs: <https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files.html>
- AWS CLI s3files reference: <https://docs.aws.amazon.com/cli/latest/reference/s3files/index.html>
