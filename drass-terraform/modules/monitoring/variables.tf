variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  type        = string
}

variable "replica_lag_threshold" {
  description = "Replica lag threshold in seconds"
  type        = number
}

variable "rpo_target_minutes" {
  description = "RPO target in minutes"
  type        = number
}

variable "enable_ec2_dr" {
  description = "Enable EC2 DR monitoring"
  type        = bool
}

variable "enable_rds_dr" {
  description = "Enable RDS DR monitoring"
  type        = bool
}

variable "enable_s3_dr" {
  description = "Enable S3 DR monitoring"
  type        = bool
}

variable "enable_dynamodb_dr" {
  description = "Enable DynamoDB DR monitoring"
  type        = bool
}

variable "enable_backup" {
  description = "Enable Backup monitoring"
  type        = bool
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

