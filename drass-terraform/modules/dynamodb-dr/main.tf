locals {
  name_prefix = var.name_prefix
}

resource "aws_dynamodb_table" "primary" {
  name           = var.table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  # Global Tables (v2017.11.29) don't support customer-managed KMS keys
  # Removing server_side_encryption block - DynamoDB defaults to AWS-managed encryption
  # This is required for global table compatibility

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-dynamodb-primary"
  })
}

resource "aws_dynamodb_table" "dr" {
  provider = aws.dr

  name           = var.table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  # Global Tables (v2017.11.29) don't support customer-managed KMS keys
  # Removing server_side_encryption block - DynamoDB defaults to AWS-managed encryption
  # This is required for global table compatibility

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-dynamodb-dr"
  })
}

# Service-linked role already exists in account - no need to create
# resource "aws_iam_service_linked_role" "dynamodb_replication" {
#   aws_service_name = "replication.dynamodb.amazonaws.com"
#   description      = "Service-linked role for DynamoDB global table replication"
# }

# Note: DynamoDB Global Tables (version 2017.11.29) don't support customer-managed KMS keys
# Tables are configured with AWS-managed encryption (AES256) for global table compatibility
# To use CMK, upgrade to Global Tables v2 (2022.08.31) via AWS Console/CLI
resource "aws_dynamodb_global_table" "global" {
  depends_on = [
    aws_dynamodb_table.primary,
    aws_dynamodb_table.dr
  ]

  name = var.table_name

  replica {
    region_name = var.primary_region
  }

  replica {
    region_name = var.dr_region
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "${local.name_prefix}-dynamodb-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "DynamoDB throttling detected"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    TableName = aws_dynamodb_table.primary.name
  }

  tags = var.tags
}

