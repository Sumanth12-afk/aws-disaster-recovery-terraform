locals {
  name_prefix = var.name_prefix
}

resource "aws_backup_vault" "primary" {
  name        = "${local.name_prefix}-backup-vault"
  kms_key_arn = var.kms_key_id != null ? var.kms_key_id : null

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-backup-vault"
  })
}

resource "aws_backup_vault" "dr" {
  provider = aws.dr

  name        = "${local.name_prefix}-backup-vault-dr"
  kms_key_arn = var.kms_key_id_dr != null ? var.kms_key_id_dr : null

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-backup-vault-dr"
  })
}

resource "aws_backup_plan" "dr_plan" {
  name = "${local.name_prefix}-backup-plan"

  rule {
    rule_name         = "${local.name_prefix}-daily-backup"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = var.backup_schedule

    lifecycle {
      cold_storage_after = 30
      delete_after       = 120
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn
    }
  }

  tags = var.tags
}

resource "aws_backup_selection" "ec2" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${local.name_prefix}-ec2-selection"
  plan_id      = aws_backup_plan.dr_plan.id

  resources = ["arn:aws:ec2:*:*:volume/*"]

  condition {
    string_equals {
      key   = "aws:ResourceTag/DR"
      value = "true"
    }
  }
}

resource "aws_backup_selection" "rds" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${local.name_prefix}-rds-selection"
  plan_id      = aws_backup_plan.dr_plan.id

  resources = ["arn:aws:rds:*:*:db:*"]
}

resource "aws_backup_selection" "dynamodb" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${local.name_prefix}-dynamodb-selection"
  plan_id      = aws_backup_plan.dr_plan.id

  resources = ["arn:aws:dynamodb:*:*:table/*"]
}

resource "aws_iam_role" "backup" {
  name = "${local.name_prefix}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Note: aws_backup_global_settings requires AWS Organizations
# Commented out for non-org accounts
# resource "aws_backup_global_settings" "settings" {
#   global_settings = {
#     "isCrossAccountBackupEnabled" = "true"
#   }
# }

resource "aws_sns_topic_policy" "backup_alerts" {
  arn = var.sns_topic_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = var.sns_topic_arn
      }
    ]
  })
}

