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

variable "primary_vpc_id" {
  description = "Primary VPC ID"
  type        = string
}

variable "primary_subnet_ids" {
  description = "Primary subnet IDs"
  type        = list(string)
}

variable "dr_vpc_id" {
  description = "DR VPC ID"
  type        = string
}

variable "dr_subnet_ids" {
  description = "DR subnet IDs"
  type        = list(string)
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
}

variable "engine" {
  description = "RDS engine"
  type        = string
}

variable "engine_version" {
  description = "RDS engine version"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "kms_key_id" {
  description = "KMS key ID for primary encryption"
  type        = string
  default     = null
}

variable "kms_key_id_dr" {
  description = "KMS key ID for DR encryption"
  type        = string
  default     = null
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

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "primary_vpc_cidr" {
  description = "Primary VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dr_vpc_cidr" {
  description = "DR VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

