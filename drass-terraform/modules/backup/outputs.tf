output "backup_vault_arn" {
  description = "AWS Backup vault ARN"
  value       = aws_backup_vault.primary.arn
}

output "backup_plan_id" {
  description = "AWS Backup plan ID"
  value       = aws_backup_plan.dr_plan.id
}

