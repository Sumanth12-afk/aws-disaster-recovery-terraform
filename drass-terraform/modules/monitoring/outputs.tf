output "alarm_names" {
  description = "List of CloudWatch alarm names"
  value = concat(
    var.enable_ec2_dr ? [aws_cloudwatch_metric_alarm.ec2_snapshot_failure[0].alarm_name] : [],
    var.enable_rds_dr ? [aws_cloudwatch_metric_alarm.rds_replica_lag[0].alarm_name, aws_cloudwatch_metric_alarm.rds_replica_status[0].alarm_name] : [],
    var.enable_s3_dr ? [aws_cloudwatch_metric_alarm.s3_replication_failure[0].alarm_name] : [],
    var.enable_dynamodb_dr ? [aws_cloudwatch_metric_alarm.dynamodb_replication_failure[0].alarm_name] : [],
    var.enable_backup ? [aws_cloudwatch_metric_alarm.backup_job_failure[0].alarm_name, aws_cloudwatch_metric_alarm.backup_failures_metric[0].alarm_name] : []
  )
}

