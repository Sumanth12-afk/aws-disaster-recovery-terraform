output "dr_vpc_id" {
  description = "DR VPC ID"
  value       = module.vpc_dr.vpc_id
}

output "dr_subnet_ids" {
  description = "DR subnet IDs"
  value       = module.vpc_dr.private_subnet_ids
}

output "backup_vault_arn" {
  description = "AWS Backup vault ARN"
  value       = var.enable_backup ? module.backup[0].backup_vault_arn : null
}

output "sns_topic_arn" {
  description = "SNS topic ARN for DR alerts"
  value       = aws_sns_topic.dr_alerts.arn
}

output "failover_lambda_arn" {
  description = "Failover Lambda function ARN"
  value       = module.lambda_failover.lambda_arn
}

output "dr_s3_replication_bucket" {
  description = "DR S3 replication bucket name"
  value       = var.enable_s3_dr ? module.s3_dr[0].dr_bucket_name : null
}

output "rds_dr_endpoint" {
  description = "RDS DR endpoint"
  value       = var.enable_rds_dr ? module.rds_dr[0].dr_endpoint : null
}

output "dynamodb_global_table_arn" {
  description = "DynamoDB global table ARN"
  value       = var.enable_dynamodb_dr ? module.dynamodb_dr[0].global_table_arn : null
}

output "primary_region" {
  description = "Primary region"
  value       = var.primary_region
}

output "dr_region" {
  description = "DR region"
  value       = var.dr_region
}

output "kms_key_id" {
  description = "Primary KMS key ID"
  value       = aws_kms_key.dr_kms.key_id
}

output "kms_key_id_dr" {
  description = "DR KMS key ID"
  value       = aws_kms_key.dr_kms_dr.key_id
}

