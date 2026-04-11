# example: ec2

Deploys S3 Files infrastructure and an EC2 instance that mounts the file system at `/mnt/s3files` on boot.

## What it creates

- S3 bucket (versioning enabled, SSE-S3)
- S3 Files file system + mount targets in each supplied subnet
- IAM file system role + compute role + EC2 instance profile, with **AmazonSSMManagedInstanceCore** attached for Session Manager
- Security groups for mount targets and compute (NFS between them, **UDP/TCP 53 egress to the VPC CIDR** for the resolver, and **HTTPS egress** for SSM and package downloads)
- EC2 instance with `user_data` that installs `amazon-efs-utils`, ensures the SSM agent is running, and mounts the file system

## Usage

Copy `terraform.tfvars.example` to `terraform.tfvars` and set your VPC and subnets (see that file for optional variables).

```bash
terraform init
terraform apply
```

Connect via SSM Session Manager (no SSH key required). The instance uses **HTTPS to the internet** for SSM (this example does not create VPC interface endpoints); use a subnet with a **public IP** or **NAT**, or tighten the rule to your corporate egress if needed.

```bash
aws ssm start-session --target "$(terraform output -raw instance_id)" --region "$(terraform output -raw aws_region)"
```

**Note:** `user_data` runs `dnf install`; the instance also needs reachability to Amazon Linux package mirrors (NAT, public subnet, or relevant VPC endpoints). If SSM still shows **offline**, confirm the subnet has a **default route** (internet gateway or NAT) so 443 to AWS APIs works, and check the agent with `sudo systemctl status amazon-ssm-agent` and `/var/log/amazon/ssm/amazon-ssm-agent.log`.
