locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "primary" {
  state = "available"
}

data "aws_availability_zones" "dr" {
  provider = aws.dr
  state    = "available"
}

module "vpc_primary" {
  source = "./modules/vpc"

  name_prefix        = local.name_prefix
  cidr_block         = var.vpc_cidr
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.primary.names, 0, min(3, length(data.aws_availability_zones.primary.names)))
  environment        = var.environment
  project_name       = var.project_name
  tags               = local.common_tags
}

module "vpc_dr" {
  source = "./modules/vpc"

  providers = {
    aws = aws.dr
  }

  name_prefix        = "${local.name_prefix}-dr"
  cidr_block         = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.dr.names, 0, min(3, length(data.aws_availability_zones.dr.names)))
  environment        = var.environment
  project_name       = var.project_name
  tags               = local.common_tags
}

resource "aws_kms_key" "dr_kms" {
  description             = "KMS key for DR encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dr-kms-key"
  })
}

resource "aws_kms_alias" "dr_kms_alias" {
  name          = "alias/${local.name_prefix}-dr-kms"
  target_key_id = aws_kms_key.dr_kms.key_id
}

resource "aws_kms_key" "dr_kms_dr" {
  provider = aws.dr

  description             = "KMS key for DR encryption in DR region"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dr-kms-key-dr"
  })
}

resource "aws_kms_alias" "dr_kms_alias_dr" {
  provider = aws.dr

  name          = "alias/${local.name_prefix}-dr-kms-dr"
  target_key_id = aws_kms_key.dr_kms_dr.key_id
}

resource "aws_sns_topic" "dr_alerts" {
  name              = "${local.name_prefix}-dr-alerts"
  display_name      = "DR Alerts"
  kms_master_key_id = var.kms_enabled ? aws_kms_key.dr_kms.arn : null

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "dr_alerts_email" {
  topic_arn = aws_sns_topic.dr_alerts.arn
  protocol  = "email"
  endpoint  = var.gmail_alert_email
}

module "ec2_dr" {
  count  = var.enable_ec2_dr ? 1 : 0
  source = "./modules/ec2-dr"

  name_prefix        = local.name_prefix
  primary_region     = var.primary_region
  dr_region          = var.dr_region
  instance_ids       = var.ec2_instance_ids
  kms_key_id         = var.kms_enabled ? aws_kms_key.dr_kms.arn : null
  sns_topic_arn      = aws_sns_topic.dr_alerts.arn
  rpo_target_minutes = var.rpo_target
  environment        = var.environment
  project_name       = var.project_name
  tags               = local.common_tags
}

module "rds_dr" {
  count  = var.enable_rds_dr ? 1 : 0
  source = "./modules/rds-dr"

  providers = {
    aws.dr = aws.dr
  }

  name_prefix            = local.name_prefix
  primary_region         = var.primary_region
  dr_region              = var.dr_region
  primary_vpc_id         = module.vpc_primary.vpc_id
  primary_subnet_ids     = module.vpc_primary.private_subnet_ids
  dr_vpc_id              = module.vpc_dr.vpc_id
  dr_subnet_ids          = module.vpc_dr.private_subnet_ids
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  engine                 = var.rds_engine
  engine_version         = var.rds_engine_version
  db_name                = var.rds_db_name
  username               = var.rds_username
  password               = var.rds_password
  kms_key_id             = var.kms_enabled ? aws_kms_key.dr_kms.arn : null
  kms_key_id_dr          = var.kms_enabled ? aws_kms_key.dr_kms_dr.arn : null
  sns_topic_arn          = aws_sns_topic.dr_alerts.arn
  replica_lag_threshold  = var.replica_lag_threshold
  rpo_target_minutes     = var.rpo_target
  primary_vpc_cidr       = module.vpc_primary.vpc_cidr_block
  dr_vpc_cidr            = module.vpc_dr.vpc_cidr_block
  environment            = var.environment
  project_name           = var.project_name
  tags                   = local.common_tags
}

module "s3_dr" {
  count  = var.enable_s3_dr ? 1 : 0
  source = "./modules/s3-dr"

  providers = {
    aws.dr = aws.dr
  }

  name_prefix    = local.name_prefix
  primary_region = var.primary_region
  dr_region      = var.dr_region
  bucket_name    = var.s3_bucket_name != "" ? var.s3_bucket_name : "${local.name_prefix}-primary-${random_id.bucket_suffix.hex}"
  kms_key_id     = var.kms_enabled ? aws_kms_key.dr_kms.arn : null
  kms_key_id_dr  = var.kms_enabled ? aws_kms_key.dr_kms_dr.arn : null
  sns_topic_arn  = aws_sns_topic.dr_alerts.arn
  environment    = var.environment
  project_name   = var.project_name
  tags           = local.common_tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

module "dynamodb_dr" {
  count  = var.enable_dynamodb_dr ? 1 : 0
  source = "./modules/dynamodb-dr"

  providers = {
    aws.dr = aws.dr
  }

  name_prefix    = local.name_prefix
  table_name     = var.dynamodb_table_name != "" ? var.dynamodb_table_name : "${local.name_prefix}-table"
  primary_region = var.primary_region
  dr_region      = var.dr_region
  kms_key_id     = null  # Global Tables v2017.11.29 don't support customer-managed KMS
  kms_key_id_dr  = null  # Global Tables v2017.11.29 don't support customer-managed KMS
  sns_topic_arn  = aws_sns_topic.dr_alerts.arn
  environment    = var.environment
  project_name   = var.project_name
  tags           = local.common_tags
}

module "backup" {
  count  = var.enable_backup ? 1 : 0
  source = "./modules/backup"

  providers = {
    aws.dr = aws.dr
  }

  name_prefix        = local.name_prefix
  primary_region     = var.primary_region
  dr_region          = var.dr_region
  backup_schedule    = var.backup_schedule
  kms_key_id         = var.kms_enabled ? aws_kms_key.dr_kms.arn : null
  kms_key_id_dr      = var.kms_enabled ? aws_kms_key.dr_kms_dr.arn : null
  sns_topic_arn      = aws_sns_topic.dr_alerts.arn
  rpo_target_minutes = var.rpo_target
  environment        = var.environment
  project_name       = var.project_name
  tags               = local.common_tags
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix            = local.name_prefix
  primary_region         = var.primary_region
  dr_region              = var.dr_region
  sns_topic_arn          = aws_sns_topic.dr_alerts.arn
  replica_lag_threshold  = var.replica_lag_threshold
  rpo_target_minutes     = var.rpo_target
  enable_ec2_dr          = var.enable_ec2_dr
  enable_rds_dr          = var.enable_rds_dr
  enable_s3_dr           = var.enable_s3_dr
  enable_dynamodb_dr     = var.enable_dynamodb_dr
  enable_backup          = var.enable_backup
  environment            = var.environment
  project_name           = var.project_name
  tags                   = local.common_tags
}

module "lambda_failover" {
  source = "./modules/lambda-failover"

  name_prefix     = local.name_prefix
  primary_region  = var.primary_region
  dr_region       = var.dr_region
  sns_topic_arn   = aws_sns_topic.dr_alerts.arn
  kms_key_id      = var.kms_enabled ? aws_kms_key.dr_kms.arn : null
  rto_target      = var.rto_target
  environment     = var.environment
  project_name    = var.project_name
  tags            = local.common_tags
}

resource "aws_cloudwatch_event_rule" "dr_workflow" {
  name        = "${local.name_prefix}-dr-workflow"
  description = "Trigger DR workflow on alarm"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda_failover" {
  rule      = aws_cloudwatch_event_rule.dr_workflow.name
  target_id = "TriggerFailoverLambda"
  arn       = module.lambda_failover.lambda_arn
}

