locals {
  name_prefix = var.name_prefix
}

resource "aws_s3_bucket" "primary" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-s3-primary"
  })
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id != null ? var.kms_key_id : null
    }
    bucket_key_enabled = var.kms_key_id != null
  }
}

resource "aws_s3_bucket" "dr" {
  provider = aws.dr

  bucket = "${var.bucket_name}-dr-${var.dr_region}"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-s3-dr"
  })
}

resource "aws_s3_bucket_versioning" "dr" {
  provider = aws.dr

  bucket = aws_s3_bucket.dr.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dr" {
  provider = aws.dr

  bucket = aws_s3_bucket.dr.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id_dr != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id_dr != null ? var.kms_key_id_dr : null
    }
    bucket_key_enabled = var.kms_key_id_dr != null
  }
}

resource "aws_iam_role" "replication" {
  name = "${local.name_prefix}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "replication" {
  name = "${local.name_prefix}-s3-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.primary.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = [
          "${aws_s3_bucket.primary.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [
          "${aws_s3_bucket.dr.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_id != null ? [var.kms_key_id] : ["*"]
        Condition = {
          StringLike = {
            "kms:ViaService" = [
              "s3.${var.primary_region}.amazonaws.com"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt"
        ]
        Resource = var.kms_key_id_dr != null ? [var.kms_key_id_dr] : ["*"]
        Condition = {
          StringLike = {
            "kms:ViaService" = [
              "s3.${var.dr_region}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "primary" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "${local.name_prefix}-replication-rule"
    status = "Enabled"

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.dr.arn
      storage_class = "STANDARD"
    }

    filter {
      prefix = ""
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.dr
  ]
}

# S3 bucket notifications for replication events are better handled via EventBridge
# Commented out to avoid configuration conflicts
# resource "aws_s3_bucket_notification" "replication_alerts" {
#   bucket = aws_s3_bucket.primary.id
#
#   topic {
#     topic_arn     = var.sns_topic_arn
#     events        = ["s3:ObjectCreated:*"]
#     filter_prefix = ""
#     filter_suffix = ""
#   }
# }

