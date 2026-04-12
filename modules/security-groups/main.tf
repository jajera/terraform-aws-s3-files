# Security groups are declared without inline rules to avoid the circular
# dependency that arises when mount-target SG and compute SG reference each other.
# Rules are attached separately via aws_security_group_rule resources.

resource "aws_security_group" "mount_target" {
  name        = "${var.name_prefix}-s3files-mt-sg"
  description = "S3 Files mount target - allows NFS inbound from compute SG"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-s3files-mt-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "compute" {
  name        = "${var.name_prefix}-s3files-compute-sg"
  description = "S3 Files compute - allows NFS outbound to mount target SG"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-s3files-compute-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# NFS inbound on mount target SG from compute SG
resource "aws_security_group_rule" "mt_inbound_nfs" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  description              = "NFS from compute SG"
  security_group_id        = aws_security_group.mount_target.id
  source_security_group_id = aws_security_group.compute.id
}

# NFS outbound on compute SG to mount target SG
resource "aws_security_group_rule" "compute_outbound_nfs" {
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  description              = "NFS to mount target SG"
  security_group_id        = aws_security_group.compute.id
  source_security_group_id = aws_security_group.mount_target.id
}

# Optional: security group for the SSM VPC interface endpoint
resource "aws_security_group" "ssm_endpoint" {
  count = var.create_ssm_endpoint_sg ? 1 : 0

  name        = "${var.name_prefix}-s3files-ssm-ep-sg"
  description = "SSM VPC endpoint - allows HTTPS inbound from compute SG"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-s3files-ssm-ep-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ssm_endpoint_inbound_https" {
  count = var.create_ssm_endpoint_sg ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "HTTPS from compute SG"
  security_group_id        = aws_security_group.ssm_endpoint[0].id
  source_security_group_id = aws_security_group.compute.id
}
