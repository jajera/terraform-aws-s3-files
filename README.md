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
<!-- END_TF_DOCS -->
