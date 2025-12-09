output "snapshot_role_arn" {
  description = "EC2 snapshot replication role ARN"
  value       = aws_iam_role.ec2_snapshot_replication.arn
}

output "snapshot_lambda_arn" {
  description = "EC2 snapshot Lambda ARN"
  value       = aws_lambda_function.ec2_snapshot.arn
}

