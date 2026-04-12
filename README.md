# terraform-aws-s3-files

Reusable Terraform module for provisioning [Amazon S3 Files](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files.html) — an NFS-compatible file system interface backed by an S3 bucket, mountable on EC2, ECS Fargate, EKS, and Lambda.

See the companion CLI walkthrough at [s3-files-workloads](https://jajera.github.io/s3-files-workloads/) for step-by-step context.

## Requirements

| Name      | Version  |
|------     |----------|
| terraform | >= 1.5.0 |
| aws       | >= 6.40  |

## Usage

```hcl
module "s3_files" {
  source = "github.com/jajera/terraform-aws-s3-files"

  aws_region   = "ap-southeast-2"
  vpc_id       = "vpc-0123456789abcdef0"
  subnet_ids   = ["subnet-aaa", "subnet-bbb"]
  bucket_name  = "my-s3-files-bucket"
  compute_type = "ecs"

  tags = {
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}
```

## Modules

| Module | Description |
| ------ | ----------- |
| [s3](./modules/s3/) | S3 bucket with versioning and encryption required by S3 Files |
| [iam](./modules/iam/) | File system role and per-compute-type client role |
| [filesystem](./modules/filesystem/) | S3 Files file system linked to the bucket |
| [mount-targets](./modules/mount-targets/) | One mount target per subnet |
| [security-groups](./modules/security-groups/) | NFS port 2049 rules between compute and mount target |
| [access-point](./modules/access-point/) | Access point required for Lambda mounts |

## Examples

| Example | Description |
| ------- | ----------- |
| [ec2](./examples/ec2/) | EC2 instance with S3 Files mounted via amazon-efs-utils |
| [ecs](./examples/ecs/) | ECS Fargate task with S3 Files volume using existing cluster |
| [eks](./examples/eks/) | EKS persistent volume via EFS CSI driver using existing cluster |
| [lambda](./examples/lambda/) | Lambda function with access point mount |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.40 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.40 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_access_point"></a> [access\_point](#module\_access\_point) | ./modules/access-point | n/a |
| <a name="module_filesystem"></a> [filesystem](#module\_filesystem) | ./modules/filesystem | n/a |
| <a name="module_iam"></a> [iam](#module\_iam) | ./modules/iam | n/a |
| <a name="module_mount_targets"></a> [mount\_targets](#module\_mount\_targets) | ./modules/mount-targets | n/a |
| <a name="module_s3"></a> [s3](#module\_s3) | ./modules/s3 | n/a |
| <a name="module_security_groups"></a> [security\_groups](#module\_security\_groups) | ./modules/security-groups | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_point_name"></a> [access\_point\_name](#input\_access\_point\_name) | Logical label for the access point (used for the Name tag when create\_access\_point = true; the AWS-assigned access point name is returned in outputs) | `string` | `"default"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for all resources | `string` | `"ap-southeast-2"` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the S3 bucket to back the file system. Must be globally unique. S3 Files requires versioning — it will be enabled automatically. | `string` | n/a | yes |
| <a name="input_compute_type"></a> [compute\_type](#input\_compute\_type) | Compute platform that will mount the file system. Selects the IAM trust principal for the compute role. | `string` | `"ec2"` | no |
| <a name="input_create_access_point"></a> [create\_access\_point](#input\_create\_access\_point) | If true, create an S3 Files access point. Required for Lambda mounts. | `bool` | `false` | no |
| <a name="input_create_compute_role"></a> [create\_compute\_role](#input\_create\_compute\_role) | If true, create the IAM role for the compute platform to mount the file system | `bool` | `true` | no |
| <a name="input_create_filesystem_role"></a> [create\_filesystem\_role](#input\_create\_filesystem\_role) | If true, create the IAM role assumed by elasticfilesystem.amazonaws.com for S3 sync | `bool` | `true` | no |
| <a name="input_create_ssm_endpoint_sg"></a> [create\_ssm\_endpoint\_sg](#input\_create\_ssm\_endpoint\_sg) | If true, create a security group for the SSM VPC interface endpoint (HTTPS 443 inbound from compute SG) | `bool` | `false` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | If true, allow Terraform to destroy the S3 bucket even when it contains objects | `bool` | `false` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ID or ARN for SSE-KMS encryption. If null, SSE-S3 (AES256) is used. S3 Files does not support SSE-C. | `string` | `null` | no |
| <a name="input_posix_gid"></a> [posix\_gid](#input\_posix\_gid) | POSIX group ID for the access point (used when create\_access\_point = true) | `number` | `1000` | no |
| <a name="input_posix_uid"></a> [posix\_uid](#input\_posix\_uid) | POSIX user ID for the access point (used when create\_access\_point = true) | `number` | `1000` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | S3 key prefix to scope the file system to a subdirectory of the bucket. If null, the root of the bucket is used. | `string` | `null` | no |
| <a name="input_root_directory"></a> [root\_directory](#input\_root\_directory) | Root directory path for the access point (used when create\_access\_point = true) | `string` | `"/"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs in which to create mount targets (one per AZ recommended) | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources | `map(string)` | <pre>{<br/>  "ManagedBy": "Terraform"<br/>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where mount targets and security groups are created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_point_arn"></a> [access\_point\_arn](#output\_access\_point\_arn) | ARN of the S3 Files access point (null when create\_access\_point = false) |
| <a name="output_access_point_id"></a> [access\_point\_id](#output\_access\_point\_id) | ID of the S3 Files access point (null when create\_access\_point = false) |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the S3 bucket |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | ID of the S3 bucket |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Regional domain name of the S3 bucket |
| <a name="output_compute_role_arn"></a> [compute\_role\_arn](#output\_compute\_role\_arn) | ARN of the compute IAM role |
| <a name="output_compute_role_name"></a> [compute\_role\_name](#output\_compute\_role\_name) | Name of the compute IAM role |
| <a name="output_compute_sg_id"></a> [compute\_sg\_id](#output\_compute\_sg\_id) | ID of the compute security group |
| <a name="output_file_system_arn"></a> [file\_system\_arn](#output\_file\_system\_arn) | ARN of the S3 Files file system |
| <a name="output_file_system_dns_name"></a> [file\_system\_dns\_name](#output\_file\_system\_dns\_name) | File system name from the S3 Files API (use mount target DNS names or file\_system\_id for mounts per AWS documentation) |
| <a name="output_file_system_id"></a> [file\_system\_id](#output\_file\_system\_id) | ID of the S3 Files file system |
| <a name="output_filesystem_role_arn"></a> [filesystem\_role\_arn](#output\_filesystem\_role\_arn) | ARN of the S3 Files file system IAM role |
| <a name="output_filesystem_role_name"></a> [filesystem\_role\_name](#output\_filesystem\_role\_name) | Name of the S3 Files file system IAM role |
| <a name="output_instance_profile_arn"></a> [instance\_profile\_arn](#output\_instance\_profile\_arn) | ARN of the EC2 instance profile (only set when compute\_type = ec2) |
| <a name="output_instance_profile_name"></a> [instance\_profile\_name](#output\_instance\_profile\_name) | Name of the EC2 instance profile (only set when compute\_type = ec2) |
| <a name="output_mount_target_ids"></a> [mount\_target\_ids](#output\_mount\_target\_ids) | Map of subnet ID to mount target ID |
| <a name="output_mount_target_sg_id"></a> [mount\_target\_sg\_id](#output\_mount\_target\_sg\_id) | ID of the mount target security group |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Derived prefix used for IAM roles, security groups, and tags (stable for a given bucket\_name) |
| <a name="output_ssm_endpoint_sg_id"></a> [ssm\_endpoint\_sg\_id](#output\_ssm\_endpoint\_sg\_id) | ID of the SSM endpoint security group (null when create\_ssm\_endpoint\_sg = false) |
<!-- END_TF_DOCS -->
