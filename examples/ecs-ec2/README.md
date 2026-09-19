# example: ecs-ec2

Deploys S3 Files infrastructure, a **new** ECS cluster, one ECS-optimized EC2 container instance, and a demo task on the **EC2 launch type** with an S3 Files volume.

Counterpart to [`examples/ecs`](../ecs/) (Fargate). Uses native `volume.s3files_volume_configuration` (AWS provider **>= 6.41**).

> **Agent requirement:** S3 Files on EC2 needs ECS agent **>= 1.104** (`ecs.capability.storage.s3-files`). This example pins the current recommended ECS-optimized AL2023 AMI via SSM so the agent is new enough.

## What it creates

- S3 bucket + S3 Files file system + mount targets (`bucket_force_destroy` defaults to **true**)
- IAM: file system role, ECS **task** role (with logs + execution policy), and a separate ECS **instance** role/profile
- Security groups with NFS 2049 between compute and mount targets, plus DNS 53 and HTTPS 443 egress on the compute SG
- ECS cluster named `{name_prefix}-s3files-ec2`
- One `t3.small` container instance (recommended ECS-optimized AMI; joins the cluster via user data)
- CloudWatch log group, native task definition, and service (`launch_type = EC2`, `awsvpc`; no `assign_public_ip`)

The demo container lists `/mnt/s3files`, writes `ecs-s3files-demo.txt` (marker `ec2-demo`), prints it to logs, then sleeps. A container health check asserts that file.

Private subnets need a **NAT gateway** (or VPC endpoints for ECS/Logs/ECR) so the instance and task ENI can reach AWS APIs on 443.

## Usage

```hcl
# terraform.tfvars
aws_region = "ap-southeast-6"
vpc_id     = "vpc-0123456789abcdef0"
subnet_ids = ["subnet-aaa", "subnet-bbb"]
```

```bash
terraform init
terraform apply
```

Confirm the mount:

```bash
aws logs tail "$(terraform output -raw log_group)" --follow
```

Tear down:

```bash
terraform destroy
```

> `terraform destroy` does not deregister ECS task definition revisions (AWS leaves them `INACTIVE`).

If destroy times out while the service stays in `DRAINING` (even with zero running tasks), force-delete it and deregister the container instance, wait until the service is `INACTIVE`, then re-run `terraform destroy`:

```bash
CLUSTER="$(terraform output -raw ecs_cluster_name)"
SERVICE="$(terraform output -raw ecs_service_name)"
aws ecs delete-service --cluster "$CLUSTER" --service "$SERVICE" --force
CI=$(aws ecs list-container-instances --cluster "$CLUSTER" --query 'containerInstanceArns[0]' --output text)
[ -n "$CI" ] && [ "$CI" != "None" ] && aws ecs deregister-container-instance --cluster "$CLUSTER" --container-instance "$CI" --force
```

If destroy fails with *data pending export to S3*, Terraform cannot pass `forceDelete` yet. Force-delete via CLI, then re-run destroy:

```bash
aws s3files delete-file-system --file-system-id "$(terraform output -raw file_system_id)" --force-delete
```

If the service fails on first apply because the container instance has not registered yet, wait for it to join the cluster and re-run `terraform apply`.
