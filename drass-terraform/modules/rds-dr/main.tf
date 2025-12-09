locals {
  name_prefix = var.name_prefix
}

resource "aws_db_subnet_group" "primary" {
  name       = "${local.name_prefix}-rds-primary-subnet-group"
  subnet_ids = var.primary_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-primary-subnet-group"
  })
}

resource "aws_db_subnet_group" "dr" {
  provider = aws.dr

  name       = "${local.name_prefix}-rds-dr-subnet-group"
  subnet_ids = var.dr_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-dr-subnet-group"
  })
}

resource "aws_security_group" "rds_primary" {
  name        = "${local.name_prefix}-rds-primary-sg"
  description = "Security group for RDS primary"
  vpc_id      = var.primary_vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.primary_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-primary-sg"
  })
}

resource "aws_security_group" "rds_dr" {
  provider = aws.dr

  name        = "${local.name_prefix}-rds-dr-sg"
  description = "Security group for RDS DR"
  vpc_id      = var.dr_vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.dr_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-dr-sg"
  })
}

resource "aws_db_instance" "primary" {
  identifier     = "${local.name_prefix}-rds-primary"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = var.kms_key_id != null
  kms_key_id            = var.kms_key_id

  db_name  = var.db_name
  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.primary.name
  vpc_security_group_ids = [aws_security_group.rds_primary.id]

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  skip_final_snapshot = false
  final_snapshot_identifier = "${local.name_prefix}-rds-primary-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-primary"
  })
}

resource "aws_db_instance" "dr_replica" {
  provider = aws.dr

  identifier     = "${local.name_prefix}-rds-dr-replica"
  replicate_source_db = aws_db_instance.primary.arn
  instance_class = var.instance_class

  storage_encrypted = var.kms_key_id_dr != null
  kms_key_id        = var.kms_key_id_dr

  db_subnet_group_name   = aws_db_subnet_group.dr.name
  vpc_security_group_ids = [aws_security_group.rds_dr.id]

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  skip_final_snapshot = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-dr-replica"
  })
}

# Manual snapshot creation - commented out as it requires the DB to be in available state
# Create snapshots manually or via AWS Backup instead
# resource "aws_db_snapshot" "manual" {
#   db_instance_identifier = aws_db_instance.primary.id
#   db_snapshot_identifier  = "${local.name_prefix}-rds-manual-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
#
#   tags = merge(var.tags, {
#     Name = "${local.name_prefix}-rds-manual-snapshot"
#   })
# }

resource "aws_db_event_subscription" "rds_events" {
  name      = "${local.name_prefix}-rds-events"
  sns_topic = var.sns_topic_arn

  source_type = "db-instance"
  source_ids  = [aws_db_instance.primary.identifier]

  event_categories = [
    "failure",
    "failover",
    "recovery",
    "restoration",
    "maintenance"
  ]

  tags = var.tags

  depends_on = [aws_db_instance.primary]
}

