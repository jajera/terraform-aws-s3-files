# module: mount-targets

Creates one S3 Files mount target per subnet using `for_each`, allowing independent lifecycle management per AZ.

**Recommended:** one subnet per Availability Zone for high availability.

The mount target security group must allow inbound NFS (TCP 2049) from the compute security group. The `security-groups` module creates both SGs and the rules.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
