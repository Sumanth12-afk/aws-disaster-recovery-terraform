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

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "rto_target" {
  description = "RTO target in minutes"
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

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

