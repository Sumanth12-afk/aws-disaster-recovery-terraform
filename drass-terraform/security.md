# DRaaS Security Implementation Guide

Comprehensive security documentation for the AWS Disaster Recovery as a Service (DRaaS) solution, covering encryption, access control, network security, and compliance considerations.

---

## 📋 Table of Contents

- [Security Overview](#security-overview)
- [Encryption at Rest](#encryption-at-rest)
- [Encryption in Transit](#encryption-in-transit)
- [Identity & Access Management](#identity--access-management)
- [Network Security](#network-security)
- [Monitoring & Auditing](#monitoring--auditing)
- [Compliance Considerations](#compliance-considerations)
- [Security Best Practices](#security-best-practices)
- [Incident Response](#incident-response)
- [Security Checklist](#security-checklist)

---

## 🔒 Security Overview

### Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Layer 1: Identity & Access Management (IAM)                │
│  ├── Service roles (Lambda, Backup)                         │
│  ├── Least privilege policies                               │
│  └── No permanent credentials                               │
│                                                              │
│  Layer 2: Network Security                                  │
│  ├── VPC isolation                                          │
│  ├── Private subnets for databases                          │
│  ├── Security groups (restrictive rules)                    │
│  └── NACLs (network-level filtering)                        │
│                                                              │
│  Layer 3: Encryption at Rest                                │
│  ├── KMS customer-managed keys                              │
│  ├── RDS encryption (AES-256)                               │
│  ├── S3 server-side encryption                              │
│  ├── DynamoDB encryption (AWS-managed)*                     │
│  ├── EBS volume encryption                                  │
│  └── Backup vault encryption                                │
│                                                              │
│  Layer 4: Encryption in Transit                             │
│  ├── TLS 1.2+ for all connections                           │
│  ├── RDS SSL/TLS connections                                │
│  ├── S3 HTTPS endpoints                                     │
│  └── API Gateway with TLS                                   │
│                                                              │
│  Layer 5: Monitoring & Auditing                             │
│  ├── CloudTrail (API logging)                               │
│  ├── CloudWatch Logs                                        │
│  ├── AWS Config (compliance)                                │
│  └── GuardDuty (threat detection)                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘

* DynamoDB uses AWS-managed encryption due to Global Tables v1 limitation
```

### Security Principles

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimum permissions required
3. **Encryption Everywhere**: Data encrypted at rest and in transit
4. **Zero Trust**: Verify all access attempts
5. **Audit Everything**: Comprehensive logging and monitoring

---

## 🔐 Encryption at Rest

### KMS Key Management

#### Primary Region KMS Key

```hcl
# main.tf
resource "aws_kms_key" "dr_kms" {
  description             = "KMS key for DR resources in primary region"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dr-kms"
  })
}

resource "aws_kms_alias" "dr_kms_alias" {
  name          = "alias/${local.name_prefix}-dr-kms"
  target_key_id = aws_kms_key.dr_kms.key_id
}
```

**Key Properties:**
- Automatic rotation: Enabled (yearly)
- Deletion window: 30 days (grace period)
- Algorithm: AES-256
- Key state: Enabled

#### DR Region KMS Key

```hcl
resource "aws_kms_key" "dr_kms_dr" {
  provider                = aws.dr
  description             = "KMS key for DR resources in DR region"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-dr-kms-dr"
    DRRegion    = "true"
  })
}
```

#### KMS Key Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow services to use the key",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "rds.amazonaws.com",
          "s3.amazonaws.com",
          "backup.amazonaws.com",
          "lambda.amazonaws.com"
        ]
      },
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": [
            "rds.us-east-1.amazonaws.com",
            "s3.us-east-1.amazonaws.com",
            "backup.us-east-1.amazonaws.com"
          ]
        }
      }
    }
  ]
}
```

### RDS Encryption

**Primary Database:**
```hcl
resource "aws_db_instance" "primary" {
  storage_encrypted = true
  kms_key_id        = var.kms_key_id  # ARN format required
  
  # Force SSL connections
  parameter_group_name = aws_db_parameter_group.mysql_ssl.name
}

resource "aws_db_parameter_group" "mysql_ssl" {
  name   = "${var.project_name}-${var.environment}-mysql-ssl"
  family = "mysql8.0"
  
  parameter {
    name  = "require_secure_transport"
    value = "1"  # Force SSL
  }
}
```

**Encryption Details:**
- Algorithm: AES-256
- Key: Customer-managed KMS key
- Transparent: No application changes needed
- Snapshots: Automatically encrypted
- Read Replica: Encrypted with DR region KMS key

**Verify Encryption:**
```bash
aws rds describe-db-instances \
  --db-instance-identifier drass-prod-rds-primary \
  --query 'DBInstances[0].[StorageEncrypted,KmsKeyId]'
```

### S3 Encryption

**Bucket Encryption Configuration:**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true  # Reduces KMS costs
  }
}
```

**Bucket Policy - Enforce Encryption:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::drass-prod-primary-*/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::drass-prod-primary-*",
        "arn:aws:s3:::drass-prod-primary-*/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

**Features:**
- Server-side encryption with KMS
- Bucket keys (reduced KMS API calls)
- Deny unencrypted uploads
- Enforce HTTPS transport

### DynamoDB Encryption

**Important Limitation:**
DynamoDB Global Tables v2017.11.29 does not support customer-managed KMS keys. AWS-managed encryption is used.

```hcl
resource "aws_dynamodb_table" "primary" {
  name           = var.table_name
  billing_mode   = "PROVISIONED"
  
  # No server_side_encryption block
  # AWS-managed encryption (AES-256) enabled by default
  
  point_in_time_recovery {
    enabled = true  # Encrypted backups
  }
}
```

**Encryption Details:**
- Algorithm: AES-256
- Key: AWS-managed (not customer-managed)
- Transparent: No application changes
- Point-in-time recovery: Encrypted
- Global Tables: All replicas encrypted

**Future Migration:**
To use customer-managed keys, migrate to Global Tables v2019.11.21:

```hcl
# Future implementation
resource "aws_dynamodb_table" "primary" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_id
  }
  
  replica {
    region_name    = "us-west-2"
    kms_key_arn    = var.kms_key_id_dr
  }
}
```

### AWS Backup Encryption

```hcl
resource "aws_backup_vault" "primary" {
  name        = "${var.project_name}-${var.environment}-backup-vault"
  kms_key_arn = var.kms_key_id
  
  tags = var.tags
}

resource "aws_backup_vault" "dr" {
  provider    = aws.dr
  name        = "${var.project_name}-${var.environment}-backup-vault-dr"
  kms_key_arn = var.kms_key_id_dr
  
  tags = merge(var.tags, {
    DRRegion = "true"
  })
}
```

**Copy Rule with Encryption:**
```hcl
copy_action {
  destination_vault_arn = aws_backup_vault.dr.arn
  
  lifecycle {
    cold_storage_after_days = 30
    delete_after_days       = 120
  }
}
```

All backup recovery points are encrypted with the vault's KMS key.

### Lambda Environment Encryption

```hcl
resource "aws_lambda_function" "failover" {
  function_name = "${var.project_name}-${var.environment}-failover"
  
  environment {
    variables = {
      PRIMARY_REGION = var.primary_region
      DR_REGION      = var.dr_region
      SNS_TOPIC_ARN  = var.sns_topic_arn
    }
  }
  
  kms_key_arn = var.kms_key_id  # Encrypts environment variables
}
```

---

## 🔐 Encryption in Transit

### TLS/SSL Configuration

#### RDS SSL Enforcement

```hcl
# modules/rds-dr/main.tf
resource "aws_db_parameter_group" "mysql_ssl" {
  name   = "${var.project_name}-${var.environment}-mysql-ssl"
  family = "mysql8.0"
  
  parameter {
    name  = "require_secure_transport"
    value = "1"
  }
  
  parameter {
    name  = "tls_version"
    value = "TLSv1.2,TLSv1.3"
  }
}
```

**Application Connection:**
```python
import pymysql

connection = pymysql.connect(
    host='drass-prod-rds-primary.xxx.us-east-1.rds.amazonaws.com',
    user='admin',
    password='password',
    database='mydb',
    ssl={'ca': '/path/to/rds-ca-2019-root.pem'},
    ssl_verify_cert=True,
    ssl_verify_identity=True
)
```

**Download RDS CA Certificate:**
```bash
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
```

#### S3 HTTPS Enforcement

```hcl
# Bucket policy enforcing HTTPS
resource "aws_s3_bucket_policy" "primary" {
  bucket = aws_s3_bucket.primary.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          "${aws_s3_bucket.primary.arn}",
          "${aws_s3_bucket.primary.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```

#### DynamoDB Encryption

DynamoDB connections automatically use TLS 1.2+. No additional configuration required.

```python
import boto3

# Automatically uses HTTPS
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('drass-table')
```

### Cross-Region Replication Security

#### RDS Replication

- Cross-region replication uses AWS's private network
- Traffic encrypted in transit within AWS network
- No public internet exposure

#### S3 Replication

```hcl
resource "aws_s3_bucket_replication_configuration" "primary" {
  # ...
  
  rule {
    id     = "replicate-all"
    status = "Enabled"
    
    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"  # Replicate encrypted objects
      }
    }
    
    destination {
      bucket        = aws_s3_bucket.dr.arn
      
      encryption_configuration {
        replica_kms_key_id = var.kms_key_id_dr  # Re-encrypt in DR region
      }
    }
  }
}
```

**Security Features:**
- Objects re-encrypted with DR region KMS key
- Traffic uses AWS private network
- Replication IAM role has minimal permissions

---

## 👤 Identity & Access Management

### IAM Roles

#### Lambda Execution Role

```hcl
# modules/lambda-failover/main.tf
resource "aws_iam_role" "lambda_failover" {
  name = "${var.project_name}-${var.environment}-lambda-failover-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_failover" {
  name = "${var.project_name}-${var.environment}-lambda-failover-policy"
  role = aws_iam_role.lambda_failover.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSFailover"
        Effect = "Allow"
        Action = [
          "rds:PromoteReadReplica",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance"
        ]
        Resource = [
          "arn:aws:rds:${var.primary_region}:*:db:${var.project_name}-*",
          "arn:aws:rds:${var.dr_region}:*:db:${var.project_name}-*"
        ]
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = var.sns_topic_arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.primary_region}:*:log-group:/aws/lambda/${var.project_name}-*"
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          var.kms_key_id,
          var.kms_key_id_dr
        ]
      }
    ]
  })
}
```

**Key Features:**
- Least privilege access
- Resource-specific permissions (not wildcard)
- Cross-region RDS access for failover
- KMS decrypt for encrypted resources

#### AWS Backup Role

```hcl
# modules/backup/main.tf
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-${var.environment}-backup-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

# AWS managed policies (least privilege)
resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}
```

#### S3 Replication Role

```hcl
# modules/s3-dr/main.tf
resource "aws_iam_role" "replication" {
  name = "${var.project_name}-${var.environment}-s3-replication-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication" {
  name = "${var.project_name}-${var.environment}-s3-replication-policy"
  role = aws_iam_role.replication.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSourceBucket"
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Sid    = "ReadSourceObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        Sid    = "WriteDestinationBucket"
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.dr.arn}/*"
      },
      {
        Sid    = "KMSPermissions"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_id
        Condition = {
          StringLike = {
            "kms:ViaService" = "s3.${var.primary_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "KMSDestination"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_id_dr
        Condition = {
          StringLike = {
            "kms:ViaService" = "s3.${var.dr_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}
```

### IAM Best Practices

✅ **Do:**
- Use IAM roles (never long-term credentials)
- Grant least privilege access
- Use resource-specific ARNs (not `*`)
- Implement MFA for human access
- Rotate credentials regularly
- Use AWS managed policies when available
- Add condition statements for additional security

❌ **Don't:**
- Embed credentials in code
- Use root account for operations
- Grant wildcard permissions
- Share IAM users/credentials
- Use overly broad policies

---

## 🌐 Network Security

### VPC Security Architecture

```
Internet
    │
    ▼
[Internet Gateway]
    │
    ├─── Public Subnet 1 (10.0.0.0/24) ─── [NAT Gateway 1]
    │                                              │
    ├─── Public Subnet 2 (10.0.1.0/24) ─── [NAT Gateway 2]
    │                                              │
    └─── Public Subnet 3 (10.0.2.0/24) ─── [NAT Gateway 3]
                                                   │
    ┌──────────────────────────────────────────────┘
    │
    ├─── Private Subnet 1 (10.0.10.0/24) ─── [RDS Primary]
    │
    ├─── Private Subnet 2 (10.0.11.0/24) ─── [RDS Standby (if Multi-AZ)]
    │
    └─── Private Subnet 3 (10.0.12.0/24) ─── [Application Servers]
```

### Security Groups

#### RDS Security Group (Primary)

```hcl
resource "aws_security_group" "rds_primary" {
  name        = "${var.project_name}-${var.environment}-rds-primary-sg"
  description = "Security group for RDS primary instance"
  vpc_id      = var.vpc_id
  
  # Inbound: Only from application security group
  ingress {
    description     = "MySQL from application"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]  # Not CIDR blocks!
  }
  
  # Outbound: None needed for database
  egress {
    description = "No outbound access required"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Can be restricted further
  }
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-primary-sg"
  })
}
```

#### Lambda Security Group

```hcl
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = var.vpc_id
  
  # Outbound: HTTPS only
  egress {
    description = "HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    description     = "MySQL to RDS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_primary.id]
  }
}
```

### Network ACLs

```hcl
# Optional: Additional layer of defense
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id
  
  # Deny all inbound by default
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "10.0.0.0/16"  # Only from VPC
    from_port  = 3306
    to_port    = 3306
  }
  
  # Allow established connections
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-private-nacl"
  })
}
```

### VPC Flow Logs

```hcl
resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}-flow-logs"
  retention_in_days = 30
  kms_key_id        = var.kms_key_id
}
```

**Analyze Flow Logs:**
```bash
# Find rejected connections
aws logs filter-log-events \
  --log-group-name /aws/vpc/drass-prod-flow-logs \
  --filter-pattern "REJECT" \
  --start-time $(date -u -d '1 hour ago' +%s000)

# Find connections from specific IP
aws logs filter-log-events \
  --log-group-name /aws/vpc/drass-prod-flow-logs \
  --filter-pattern "1.2.3.4" \
  --start-time $(date -u -d '1 hour ago' +%s000)
```

---

## 📊 Monitoring & Auditing

### CloudTrail Configuration

```hcl
resource "aws_cloudtrail" "dr" {
  name                          = "${var.project_name}-${var.environment}-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_id
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.primary.arn}/"]
    }
    
    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda:*:*:function/*"]
    }
  }
  
  insight_selector {
    insight_type = "ApiCallRateInsight"
  }
}
```

### GuardDuty Integration

```hcl
resource "aws_guardduty_detector" "primary" {
  enable = true
  
  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }
}

# Send GuardDuty findings to SNS
resource "aws_cloudwatch_event_rule" "guardduty" {
  name = "${var.project_name}-${var.environment}-guardduty-findings"
  
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7, 8, 9]  # High and critical only
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}
```

### AWS Config Rules

```hcl
resource "aws_config_configuration_recorder" "dr" {
  name     = "${var.project_name}-${var.environment}-config"
  role_arn = aws_iam_role.config.arn
  
  recording_group {
    all_supported = true
    
    recording_strategy {
      use_only = "ALL_SUPPORTED_RESOURCE_TYPES"
    }
  }
}

# Example: Check RDS encryption
resource "aws_config_config_rule" "rds_encryption" {
  name = "${var.project_name}-rds-storage-encrypted"
  
  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }
  
  depends_on = [aws_config_configuration_recorder.dr]
}

# Example: Check S3 bucket encryption
resource "aws_config_config_rule" "s3_bucket_encryption" {
  name = "${var.project_name}-s3-default-encryption-kms"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_DEFAULT_ENCRYPTION_KMS"
  }
}
```

### Security Monitoring Dashboard

**Create CloudWatch Dashboard:**
```hcl
resource "aws_cloudwatch_dashboard" "security" {
  dashboard_name = "${var.project_name}-${var.environment}-security"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", { stat = "Sum" }],
            ["AWS/Lambda", "Errors", { stat = "Sum" }],
            ["AWS/S3", "4xxErrors", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.primary_region
          title  = "Security Metrics"
        }
      }
    ]
  })
}
```

---

## 📋 Compliance Considerations

### GDPR Compliance

- ✅ Data encryption at rest and in transit
- ✅ Data residency (specify regions)
- ✅ Right to erasure (S3 lifecycle, RDS deletion)
- ✅ Audit logging (CloudTrail)
- ⚠️ Data processing agreements with AWS required

### HIPAA Compliance

- ✅ KMS encryption (Business Associate Addendum required)
- ✅ Audit logging
- ✅ Access controls (IAM)
- ✅ Backup and recovery
- ⚠️ BAA must be signed with AWS

### PCI DSS Compliance

- ✅ Strong encryption (Level 1: Requirement 3)
- ✅ Access controls (Requirement 7)
- ✅ Logging and monitoring (Requirement 10)
- ✅ Network segmentation (Requirement 1)
- ⚠️ Regular penetration testing required

### SOC 2 Type II

- ✅ Security (encryption, access control)
- ✅ Availability (DR setup, 99.9% uptime)
- ✅ Confidentiality (data encryption)
- ✅ Processing Integrity (CloudTrail logging)
- ⚠️ Annual audit required

---

## ✅ Security Best Practices

### Operational Security

1. **Regular Security Audits**
```bash
# Run AWS Security Hub
aws securityhub get-findings \
  --filters '{"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}'

# Check IAM credential report
aws iam generate-credential-report
aws iam get-credential-report --output text | base64 --decode > credential-report.csv
```

2. **Patch Management**
- Enable RDS automatic minor version upgrades
- Use AWS Systems Manager for EC2 patching
- Lambda runtime updates (Python 3.12 → 3.13)

3. **Secrets Management**
```hcl
# Use Secrets Manager for database passwords
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.project_name}-${var.environment}-db-password"
  
  kms_key_id = var.kms_key_id
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}
```

4. **Network Monitoring**
```bash
# Enable VPC Flow Logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flow-logs
```

5. **Access Review**
```bash
# List all IAM users
aws iam list-users

# Check user access keys age
aws iam get-access-key-last-used --access-key-id AKIAIOSFODNN7EXAMPLE

# Review IAM policies
aws iam get-policy-version \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess \
  --version-id v1
```

---

## 🚨 Incident Response

### Security Incident Playbook

#### 1. Unauthorized Access Detected

```bash
# Immediate actions:
# 1. Disable compromised credentials
aws iam delete-access-key --user-name compromised-user --access-key-id AKIAIOSFODNN7

# 2. Rotate all secrets
aws secretsmanager rotate-secret --secret-id drass-prod-db-password

# 3. Review CloudTrail logs
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=compromised-user \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --max-results 1000

# 4. Enable MFA delete on S3
aws s3api put-bucket-versioning \
  --bucket drass-prod-primary \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::123456789012:mfa/root-account-mfa-device 123456"

# 5. Notify security team via SNS
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:123456789012:security-incidents \
  --subject "SECURITY INCIDENT: Unauthorized Access Detected" \
  --message "Immediate action required. User: compromised-user. Time: $(date)"
```

#### 2. Data Exfiltration Suspected

```bash
# 1. Review S3 access logs
aws s3api get-bucket-logging --bucket drass-prod-primary

# 2. Check large data transfers
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BytesDownloaded \
  --dimensions Name=BucketName,Value=drass-prod-primary \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum

# 3. Block suspicious IPs
aws ec2 modify-network-interface-attribute \
  --network-interface-id eni-xxxxx \
  --groups sg-block-all

# 4. Take RDS snapshot for forensics
aws rds create-db-snapshot \
  --db-instance-identifier drass-prod-rds-primary \
  --db-snapshot-identifier forensic-snapshot-$(date +%Y%m%d-%H%M%S)
```

#### 3. Ransomware/Cryptolocker

```bash
# 1. Isolate affected resources
aws ec2 modify-instance-attribute \
  --instance-id i-xxxxx \
  --groups sg-quarantine

# 2. Restore from backups
aws backup start-restore-job \
  --recovery-point-arn <backup-arn> \
  --iam-role-arn <restore-role-arn> \
  --metadata <restore-metadata>

# 3. Check S3 versioning
aws s3api list-object-versions \
  --bucket drass-prod-primary \
  --prefix infected-file.txt

# 4. Restore S3 objects
aws s3api restore-object \
  --bucket drass-prod-primary \
  --key infected-file.txt \
  --version-id <version-before-encryption>
```

---

## ✅ Security Checklist

### Pre-Deployment

- [ ] KMS keys created with rotation enabled
- [ ] All resources configured with encryption at rest
- [ ] IAM roles follow least privilege
- [ ] No hardcoded credentials in code
- [ ] Security groups restrict access (no 0.0.0.0/0 on ingress)
- [ ] VPC Flow Logs enabled
- [ ] CloudTrail enabled and logging to S3
- [ ] S3 buckets have versioning enabled
- [ ] S3 bucket policies enforce HTTPS
- [ ] RDS instances enforce SSL connections
- [ ] Backup encryption configured
- [ ] SNS topic for security alerts created

### Post-Deployment

- [ ] CloudTrail logs are being generated
- [ ] VPC Flow Logs are being generated
- [ ] CloudWatch alarms are active
- [ ] SNS notifications are working
- [ ] GuardDuty is enabled (if using)
- [ ] AWS Config is recording
- [ ] Security Hub is enabled (if using)
- [ ] IAM Access Analyzer is enabled
- [ ] All resources are tagged appropriately
- [ ] DR readiness check script runs successfully

### Monthly Security Review

- [ ] Review CloudTrail logs for suspicious activity
- [ ] Check for failed login attempts
- [ ] Review IAM users and access keys
- [ ] Verify MFA is enabled for all users
- [ ] Check for unused resources
- [ ] Review Security Hub findings
- [ ] Review GuardDuty findings
- [ ] Verify backups are being created
- [ ] Test backup restore process
- [ ] Review KMS key policies
- [ ] Check for open security group rules
- [ ] Verify CloudWatch alarms are functioning
- [ ] Run DR readiness check
- [ ] Update incident response playbooks

### Quarterly Security Tasks

- [ ] Rotate all access keys
- [ ] Rotate database passwords
- [ ] Review and update IAM policies
- [ ] Perform DR failover test
- [ ] Review and update security groups
- [ ] Audit S3 bucket policies
- [ ] Review CloudTrail retention
- [ ] Update Lambda runtimes
- [ ] Patch RDS if needed
- [ ] Review compliance reports
- [ ] Conduct security awareness training
- [ ] Update documentation

---

## 📚 Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [AWS Security Hub](https://aws.amazon.com/security-hub/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

---

**Security is everyone's responsibility. Stay vigilant!** 🛡️

