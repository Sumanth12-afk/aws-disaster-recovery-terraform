output "primary_endpoint" {
  description = "RDS primary endpoint"
  value       = aws_db_instance.primary.endpoint
}

output "dr_endpoint" {
  description = "RDS DR endpoint"
  value       = aws_db_instance.dr_replica.endpoint
}

output "primary_identifier" {
  description = "RDS primary identifier"
  value       = aws_db_instance.primary.identifier
}

output "dr_identifier" {
  description = "RDS DR identifier"
  value       = aws_db_instance.dr_replica.identifier
}

