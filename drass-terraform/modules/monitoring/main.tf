locals {
  name_prefix = var.name_prefix
}

resource "aws_cloudwatch_metric_alarm" "ec2_snapshot_failure" {
  count = var.enable_ec2_dr ? 1 : 0

  alarm_name          = "${local.name_prefix}-ec2-snapshot-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "EC2 snapshot replication failure"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = "${local.name_prefix}-ec2-snapshot"
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_replica_lag" {
  count = var.enable_rds_dr ? 1 : 0

  alarm_name          = "${local.name_prefix}-rds-replica-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReplicaLag"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.replica_lag_threshold
  alarm_description   = "RDS replica lag exceeds threshold"
  alarm_actions       = [var.sns_topic_arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_replica_status" {
  count = var.enable_rds_dr ? 1 : 0

  alarm_name          = "${local.name_prefix}-rds-replica-status"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "RDS replica connection issues"
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "breaching"

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "s3_replication_failure" {
  count = var.enable_s3_dr ? 1 : 0

  alarm_name          = "${local.name_prefix}-s3-replication-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ReplicationLatency"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Average"
  threshold           = var.rpo_target_minutes * 60
  alarm_description   = "S3 replication latency exceeds RPO"
  alarm_actions       = [var.sns_topic_arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_replication_failure" {
  count = var.enable_dynamodb_dr ? 1 : 0

  alarm_name          = "${local.name_prefix}-dynamodb-replication-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReplicationLatency"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Average"
  threshold           = var.rpo_target_minutes * 60
  alarm_description   = "DynamoDB replication latency exceeds RPO"
  alarm_actions       = [var.sns_topic_arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "backup_job_failure" {
  count = var.enable_backup ? 1 : 0

  alarm_name          = "${local.name_prefix}-backup-job-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfBackupJobsCompleted"
  namespace           = "AWS/Backup"
  period              = 3600
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "AWS Backup job failures detected"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    BackupVaultName = "${local.name_prefix}-backup-vault"
  }

  tags = var.tags
}

# CloudWatch log metric filter requires log group to exist first
# Creating log group or removing filter - log group is created automatically by AWS Backup
resource "aws_cloudwatch_log_group" "backup" {
  count = var.enable_backup ? 1 : 0

  name              = "/aws/backup"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "backup_failures" {
  count = var.enable_backup ? 1 : 0

  name           = "${local.name_prefix}-backup-failures"
  log_group_name = aws_cloudwatch_log_group.backup[0].name
  pattern        = "[timestamp, request_id, level=ERROR, ...]"

  metric_transformation {
    name      = "BackupFailures"
    namespace = "DRaaS/Backup"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "backup_failures_metric" {
  count = var.enable_backup ? 1 : 0

  alarm_name          = "${local.name_prefix}-backup-failures-metric"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BackupFailures"
  namespace           = "DRaaS/Backup"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Backup failures detected in logs"
  alarm_actions       = [var.sns_topic_arn]

  tags = var.tags
}

