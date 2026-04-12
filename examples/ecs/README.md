# example: ecs

Deploys S3 Files infrastructure and runs an ECS Fargate task on an **existing** ECS cluster with the S3 Files volume mounted.

> **Note:** `aws_ecs_task_definition` does not yet support `s3filesVolumeConfiguration` natively. This example registers the task definition via `terraform_data` + `local-exec` calling `aws ecs register-task-definition` directly. Requires AWS CLI v2.34.26+ on the machine running `terraform apply`.

> **Fargate and Managed Instances only.** S3 Files volumes are not supported on the ECS EC2 launch type.

## What it creates

- S3 bucket + S3 Files file system + mount targets (`bucket_force_destroy` defaults to **true** for easier teardown)
- IAM roles (file system role + ECS compute role) with **CloudWatch Logs** permissions for `awslogs` and **AmazonECSTaskExecutionRolePolicy** for ECR pull (same role is both execution and task role in this demo)
- Security groups, including **DNS (53) and HTTPS (443) egress** on the compute SG so Fargate can reach **CloudWatch Logs** (and ECR) on the task ENI
- CloudWatch log group `/ecs/{name_prefix}-s3files`
- ECS task definition (via `local-exec`) with `s3filesVolumeConfiguration`; the container **lists the mount, `df`s it, writes** `ecs-s3files-demo.txt` under `/mnt/s3files`, **prints it** (check CloudWatch logs), then sleeps; a **container `healthCheck`** (`CMD-SHELL`) asserts that file exists and still contains `fargate-demo` every 30s after a 90s start period
- ECS service on the existing cluster with **`launch_type = FARGATE`**

Private subnets with **`assign_public_ip = false`** need a **NAT gateway** (or VPC endpoints for Logs/ECR) so `0.0.0.0/0:443` egress can reach AWS APIs.

## Usage

```hcl
# terraform.tfvars
aws_region       = "ap-southeast-2"
name_prefix      = "demo"
bucket_name      = "my-unique-s3files-bucket"
vpc_id           = "vpc-0123456789abcdef0"
subnet_ids       = ["subnet-aaa", "subnet-bbb"]
ecs_cluster_name = "my-existing-cluster"
```

```bash
terraform init
terraform apply
```
