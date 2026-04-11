# example: lambda

Deploys S3 Files infrastructure with an access point and a Lambda function that mounts the file system at `/mnt/s3files`.

Lambda **requires an access point** — it cannot mount a file system by ID alone.

## What it creates

- S3 bucket + S3 Files file system + mount targets (`force_destroy` on the bucket defaults to **true** for easy teardown)
- IAM roles (file system role + Lambda compute role) plus **AWSLambdaVPCAccessExecutionRole** for ENIs
- Security groups with **DNS (53)** and **HTTPS (443)** egress from the compute SG (same idea as `examples/ec2`)
- S3 Files access point (UID/GID 1000, root `/lambda`)
- CloudWatch log group + inline policy for log writes
- Lambda function (Python 3.14) with `file_system_config` referencing the access point

## Usage

Copy `terraform.tfvars.example` to `terraform.tfvars` and set your VPC and subnets.

Subnets should have a **NAT gateway** (or equivalent) so the Lambda ENI can reach AWS APIs on port 443; NFS to mount targets stays within the VPC.

```bash
terraform init
terraform apply
```

## Put a file in the bucket (AWS CLI)

This example’s access point root is **`/lambda`** in the bucket, so use the **`lambda/`** prefix on the key:

```bash
aws s3 cp - "s3://$(terraform output -raw bucket_name)/lambda/hello.txt" --region "$(terraform output -raw aws_region)" <<< hello
```

Invoke the function to list the mounted path:

```bash
aws lambda invoke \
  --function-name "$(terraform output -raw lambda_function_name)" \
  --region "$(terraform output -raw aws_region)" \
  --payload '{}' \
  response.json && cat response.json
```
