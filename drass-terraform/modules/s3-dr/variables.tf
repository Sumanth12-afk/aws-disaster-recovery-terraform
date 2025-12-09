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

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
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

