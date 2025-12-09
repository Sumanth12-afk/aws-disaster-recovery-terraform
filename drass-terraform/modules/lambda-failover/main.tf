locals {
  name_prefix = var.name_prefix
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/failover_lambda.py"
  output_path = "${path.module}/failover_lambda.zip"
}

resource "aws_lambda_function" "failover" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.name_prefix}-failover"
  role            = aws_iam_role.lambda_failover.arn
  handler         = "failover_lambda.handler"
  runtime         = "python3.12"
  timeout         = 900
  memory_size     = 512

  environment {
    variables = {
      DR_REGION     = var.dr_region
      SNS_TOPIC_ARN = var.sns_topic_arn
      RTO_TARGET    = var.rto_target
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "lambda_failover" {
  name = "${local.name_prefix}-lambda-failover-role"

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

resource "aws_iam_role_policy" "lambda_failover" {
  name = "${local.name_prefix}-lambda-failover-policy"
  role = aws_iam_role.lambda_failover.id

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
          "rds:PromoteReadReplica",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "dynamodb:DescribeTable",
          "s3:GetBucketReplication",
          "s3:PutBucketReplication",
          "backup:StartRestoreJob",
          "backup:DescribeBackupJob"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt"
        ]
        Resource = var.kms_key_id != null ? [var.kms_key_id] : ["*"]
      }
    ]
  })
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover.function_name
  principal     = "events.amazonaws.com"
}

