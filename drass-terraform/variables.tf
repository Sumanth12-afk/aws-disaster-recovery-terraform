variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "gmail_alert_email" {
  description = "Gmail address for DR alerts"
  type        = string
}

variable "enable_ec2_dr" {
  description = "Enable EC2 DR replication"
  type        = bool
  default     = true
}

variable "enable_rds_dr" {
  description = "Enable RDS DR replication"
  type        = bool
  default     = true
}

variable "enable_s3_dr" {
  description = "Enable S3 DR replication"
  type        = bool
  default     = true
}

variable "enable_dynamodb_dr" {
  description = "Enable DynamoDB DR replication"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable AWS Backup"
  type        = bool
  default     = true
}

variable "kms_enabled" {
  description = "Enable KMS encryption"
  type        = bool
  default     = true
}

variable "rpo_target" {
  description = "Recovery Point Objective in minutes"
  type        = number
  default     = 60
}

variable "rto_target" {
  description = "Recovery Time Objective in minutes"
  type        = number
  default     = 120
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = []
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_engine" {
  description = "RDS engine"
  type        = string
  default     = "mysql"
}

variable "rds_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "8.0"
}

variable "rds_db_name" {
  description = "RDS database name"
  type        = string
  default     = "drassdb"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "s3_bucket_name" {
  description = "S3 bucket name for replication"
  type        = string
  default     = ""
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "drass-table"
}

variable "ec2_instance_ids" {
  description = "List of EC2 instance IDs to protect"
  type        = list(string)
  default     = []
}

variable "rds_instance_id" {
  description = "RDS instance identifier"
  type        = string
  default     = ""
}

variable "backup_schedule" {
  description = "AWS Backup schedule expression"
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "replica_lag_threshold" {
  description = "RDS replica lag threshold in seconds"
  type        = number
  default     = 60
}

