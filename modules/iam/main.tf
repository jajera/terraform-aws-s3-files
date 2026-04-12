locals {
  compute_service_principals = {
    ec2    = "ec2.amazonaws.com"
    ecs    = "ecs-tasks.amazonaws.com"
    lambda = "lambda.amazonaws.com"
    eks    = "pods.eks.amazonaws.com"
  }
  compute_principal = local.compute_service_principals[var.compute_type]
}

#
# File system IAM role — assumed by elasticfilesystem.amazonaws.com
# to sync objects between the file system and the S3 bucket.
#
resource "aws_iam_role" "filesystem" {
  count = var.create_filesystem_role ? 1 : 0

  name        = "${var.name_prefix}-s3files-filesystem-role"
  description = "Assumed by S3 Files to read/write the linked S3 bucket and manage EventBridge sync rules"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "elasticfilesystem.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        # Per https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-prereq-policies.html
        # Principal is elasticfilesystem.amazonaws.com but SourceArn must use the s3files ARN namespace.
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3files:${var.aws_region}:${var.account_id}:file-system/*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "filesystem" {
  count = var.create_filesystem_role ? 1 : 0

  name = "S3FilesFileSystemPolicy"
  role = aws_iam_role.filesystem[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "S3BucketPermissions"
          Effect = "Allow"
          Action = [
            "s3:GetBucketLocation",
            "s3:GetBucketNotification",
            "s3:GetBucketVersioning",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:ListBucketVersions",
            "s3:PutBucketNotification"
          ]
          Resource = var.bucket_arn
          Condition = {
            StringEquals = {
              "aws:ResourceAccount" = var.account_id
            }
          }
        },
        {
          Sid    = "S3ObjectPermissions"
          Effect = "Allow"
          Action = [
            "s3:AbortMultipartUpload",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:HeadObject",
            "s3:ListMultipartUploadParts",
            "s3:PutObject",
            "s3:PutObjectAcl"
          ]
          Resource = "${var.bucket_arn}/*"
          Condition = {
            StringEquals = {
              "aws:ResourceAccount" = var.account_id
            }
          }
        },
        {
          Sid    = "EventBridgeManage"
          Effect = "Allow"
          Action = [
            "events:DeleteRule",
            "events:DisableRule",
            "events:EnableRule",
            "events:PutRule",
            "events:PutTargets",
            "events:RemoveTargets"
          ]
          Resource = "arn:aws:events:${var.aws_region}:${var.account_id}:rule/DO-NOT-DELETE-S3-Files*"
          Condition = {
            StringEquals = {
              "events:ManagedBy" = "elasticfilesystem.amazonaws.com"
            }
          }
        },
        {
          Sid    = "EventBridgeRead"
          Effect = "Allow"
          Action = [
            "events:DescribeRule",
            "events:ListRuleNamesByTarget",
            "events:ListRules",
            "events:ListTargetsByRule"
          ]
          Resource = "arn:aws:events:${var.aws_region}:${var.account_id}:rule/*"
        }
      ],
      var.kms_key_arn != null ? [
        {
          Sid    = "UseKmsKeyWithS3Files"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:Encrypt",
            "kms:GenerateDataKey",
            "kms:GenerateDataKeyWithoutPlaintext",
            "kms:ReEncryptFrom",
            "kms:ReEncryptTo"
          ]
          Resource = var.kms_key_arn
          Condition = {
            StringLike = {
              "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
              "kms:EncryptionContext:aws:s3:arn" = [
                var.bucket_arn,
                "${var.bucket_arn}/*"
              ]
            }
          }
        }
      ] : []
    )
  })
}

#
# Compute IAM role — assumed by the chosen compute platform to mount the file system.
#
resource "aws_iam_role" "compute" {
  count = var.create_compute_role ? 1 : 0

  name        = "${var.name_prefix}-s3files-${var.compute_type}-role"
  description = "Allows ${var.compute_type} to mount S3 Files and read objects directly from the bucket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = local.compute_principal
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "compute_s3files" {
  count = var.create_compute_role ? 1 : 0

  name = "S3FilesClientPolicy"
  role = aws_iam_role.compute[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3FilesMount"
        Effect = "Allow"
        Action = [
          "s3files:ClientMount",
          "s3files:ClientWrite",
          "s3files:ClientRootAccess"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "compute_s3" {
  count = var.create_compute_role ? 1 : 0

  name = "S3ReadPolicy"
  role = aws_iam_role.compute[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Read"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/*"
        ]
      }
    ]
  })
}

# EC2 instance profile — required for EC2 to use the role
resource "aws_iam_instance_profile" "compute" {
  count = var.create_compute_role && var.compute_type == "ec2" ? 1 : 0

  name = "${var.name_prefix}-s3files-instance-profile"
  role = aws_iam_role.compute[0].name

  tags = var.tags
}
