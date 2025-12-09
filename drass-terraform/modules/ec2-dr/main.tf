locals {
  name_prefix = var.name_prefix
}

resource "aws_iam_role" "ec2_snapshot_replication" {
  name = "${local.name_prefix}-ec2-snapshot-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "ec2_snapshot_replication" {
  name = "${local.name_prefix}-ec2-snapshot-replication-policy"
  role = aws_iam_role.ec2_snapshot_replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:CopySnapshot"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:CreateGrant"
        ]
        Resource = var.kms_key_id != null ? [var.kms_key_id] : ["*"]
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "ec2_snapshot_schedule" {
  name                = "${local.name_prefix}-ec2-snapshot-schedule"
  description         = "Schedule EC2 snapshots for DR"
  schedule_expression = "rate(${var.rpo_target_minutes} minutes)"

  tags = var.tags
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/snapshot_lambda.py"
  output_path = "${path.module}/snapshot_lambda.zip"
}

resource "aws_lambda_function" "ec2_snapshot" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.name_prefix}-ec2-snapshot"
  role            = aws_iam_role.lambda_snapshot.arn
  handler         = "snapshot_lambda.handler"
  runtime         = "python3.12"
  timeout         = 300

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      INSTANCE_IDS     = join(",", var.instance_ids)
      DR_REGION        = var.dr_region
      KMS_KEY_ID       = var.kms_key_id != null ? var.kms_key_id : ""
      SNS_TOPIC_ARN    = var.sns_topic_arn
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "lambda_snapshot" {
  name = "${local.name_prefix}-lambda-snapshot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_snapshot" {
  name = "${local.name_prefix}-lambda-snapshot-policy"
  role = aws_iam_role.lambda_snapshot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:CopySnapshot",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:CreateGrant"
        ]
        Resource = var.kms_key_id != null ? [var.kms_key_id] : ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "ec2_snapshot" {
  rule      = aws_cloudwatch_event_rule.ec2_snapshot_schedule.name
  target_id = "TriggerEC2Snapshot"
  arn       = aws_lambda_function.ec2_snapshot.arn
}

resource "aws_lambda_permission" "ec2_snapshot" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_snapshot.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_snapshot_schedule.arn
}

