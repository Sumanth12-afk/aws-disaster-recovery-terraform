output "primary_bucket_name" {
  description = "Primary S3 bucket name"
  value       = aws_s3_bucket.primary.id
}

output "dr_bucket_name" {
  description = "DR S3 bucket name"
  value       = aws_s3_bucket.dr.id
}

output "replication_role_arn" {
  description = "S3 replication role ARN"
  value       = aws_iam_role.replication.arn
}

