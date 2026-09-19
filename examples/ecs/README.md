# example: ecs

Deploys S3 Files infrastructure and runs an ECS Fargate task on an **existing** ECS cluster with the S3 Files volume mounted.

Uses native `volume.s3files_volume_configuration` (AWS provider **>= 6.41**).

> **EC2 launch type:** see [`examples/ecs-ec2`](../ecs-ec2/) for the same volume wiring on ECS/EC2 capacity.

## What it creates

- S3 bucket + S3 Files file system + mount targets (`bucket_force_destroy` defaults to **true** for easier teardown)
- IAM roles (file system role + ECS compute role) with **CloudWatch Logs** permissions for `awslogs` and **AmazonECSTaskExecutionRolePolicy** for ECR pull (same role is both execution and task role in this demo)
- Security groups, including **DNS (53) and HTTPS (443) egress** on the compute SG so Fargate can reach **CloudWatch Logs** (and ECR) on the task ENI
- CloudWatch log group `/ecs/{name_prefix}-s3files` (`name_prefix` is derived from the bucket name)
- ECS task definition with `s3files_volume_configuration`; the container **lists the mount, `df`s it, writes** `ecs-s3files-demo.txt` under `/mnt/s3files`, **prints it** (check CloudWatch logs), then sleeps; a **container `healthCheck`** (`CMD-SHELL`) asserts that file exists and still contains `fargate-demo` every 30s after a 90s start period
- ECS service on the existing cluster with **`launch_type = FARGATE`**

Private subnets with **`assign_public_ip = false`** need a **NAT gateway** (or VPC endpoints for Logs/ECR) so `0.0.0.0/0:443` egress can reach AWS APIs.

## Usage

```hcl
# terraform.tfvars
aws_region       = "ap-southeast-6"
vpc_id           = "vpc-0123456789abcdef0"
subnet_ids       = ["subnet-aaa", "subnet-bbb"]
ecs_cluster_name = "my-existing-cluster"
```

```bash
terraform init
terraform apply
```

Confirm the mount:

```bash
aws logs tail "$(terraform output -raw log_group)" --follow --region ap-southeast-6
```

Tear down:

```bash
terraform destroy
```

> `terraform destroy` does not deregister ECS task definition revisions (AWS leaves them `INACTIVE`).

If destroy fails with *data pending export to S3*, Terraform cannot pass `forceDelete` yet. Force-delete via CLI, then re-run destroy:

```bash
aws s3files delete-file-system --file-system-id "$(terraform output -raw file_system_id)" --force-delete
```
