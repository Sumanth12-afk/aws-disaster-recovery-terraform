output "global_table_arn" {
  description = "DynamoDB global table ARN"
  value       = aws_dynamodb_global_table.global.arn
}

output "primary_table_name" {
  description = "Primary DynamoDB table name"
  value       = aws_dynamodb_table.primary.name
}

output "dr_table_name" {
  description = "DR DynamoDB table name"
  value       = aws_dynamodb_table.dr.name
}

