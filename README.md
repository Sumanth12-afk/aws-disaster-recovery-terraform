# AWS Disaster Recovery as a Service (DRaaS)

[![Terraform](https://img.shields.io/badge/Terraform-v1.0+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Multi--Region-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A complete, production-ready **Disaster Recovery as a Service (DRaaS)** solution built with Terraform that provides automated cross-region replication, monitoring, and failover capabilities for AWS infrastructure.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [DR Operations](#dr-operations)
- [Cost Estimation](#cost-estimation)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

This DRaaS solution provides comprehensive disaster recovery capabilities across AWS regions with:

- **Multi-Region Architecture**: Primary (us-east-1) and DR (us-west-2) regions
- **Automated Replication**: RDS, S3, DynamoDB cross-region replication
- **Continuous Monitoring**: 8 CloudWatch alarms with email notifications
- **Automated Backups**: Daily backups with cross-region copying
- **Failover Automation**: Lambda-based orchestration for DR scenarios
- **Infrastructure as Code**: 100% Terraform managed
- **Security First**: KMS encryption, security groups, IAM least privilege

### Recovery Objectives

| Component | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) |
|-----------|------------------------------|--------------------------------|
| RDS Database | 10-15 minutes | ~60 seconds |
| S3 Storage | Immediate | ~15 minutes |
| DynamoDB | < 1 second | < 1 second |
| EC2 Snapshots | 30-60 minutes | 24 hours |
| **Full Region** | **45-120 minutes** | **~1 minute** |

---

## 🏗️ Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                    PRIMARY REGION (us-east-1)                │
├─────────────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                                           │
│  ├── 3 Public Subnets + 3 Private Subnets                   │
│  ├── Internet Gateway + 3 NAT Gateways                      │
│  ├── RDS MySQL 8.0 (Primary)                                │
│  ├── S3 Bucket (Primary)                                    │
│  └── DynamoDB Table                                         │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Cross-Region Replication
                          │ (Automated & Continuous)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     DR REGION (us-west-2)                    │
├─────────────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                                           │
│  ├── 3 Public Subnets + 3 Private Subnets                   │
│  ├── Internet Gateway + 3 NAT Gateways                      │
│  ├── RDS MySQL 8.0 (Read Replica)                           │
│  ├── S3 Bucket (Replica)                                    │
│  └── DynamoDB Table (Global Table)                          │
└─────────────────────────────────────────────────────────────┘
```

### Components

#### 1. **Network Infrastructure**
- Dual-region VPC setup with 3 AZs each
- Public subnets for internet-facing resources
- Private subnets for databases and internal services
- NAT Gateways for outbound internet access
- Security groups for access control

#### 2. **Database Layer**
- **RDS MySQL 8.0**: Primary with cross-region read replica
- **DynamoDB**: Global tables with bi-directional replication
- Automated backups and point-in-time recovery
- KMS encryption at rest

#### 3. **Storage Layer**
- **S3**: Cross-region replication with versioning
- Lifecycle policies for cost optimization
- Server-side encryption with KMS
- Delete marker replication

#### 4. **Backup & Recovery**
- AWS Backup with daily schedules (2 AM UTC)
- Cross-region backup copies
- 35-day retention (primary), 120-day retention (DR)
- Cold storage after 30 days

#### 5. **Automation**
- **EC2 Snapshot Lambda**: Daily EBS snapshots with cross-region copy
- **Failover Lambda**: Automated DR failover orchestration
- EventBridge rules for scheduling and triggering

#### 6. **Monitoring & Alerting**
- 8 CloudWatch alarms for DR health monitoring
- SNS email notifications for critical events
- Custom metrics from CloudWatch Logs
- Real-time alerting on failures

#### 7. **Security**
- KMS encryption keys (primary + DR)
- IAM roles with least privilege access
- Security groups with restrictive rules
- VPC isolation and network segmentation

---

## ✨ Features

### Automated Replication
- ✅ RDS cross-region async replication
- ✅ S3 real-time object replication
- ✅ DynamoDB bi-directional global tables
- ✅ Daily EC2 snapshot replication
- ✅ Cross-region backup copies

### High Availability
- ✅ Multi-AZ deployment (3 AZs per region)
- ✅ NAT Gateway redundancy
- ✅ RDS read replica for failover
- ✅ S3 versioning for data protection
- ✅ DynamoDB point-in-time recovery

### Security & Compliance
- ✅ KMS encryption at rest (all services)
- ✅ TLS/SSL encryption in transit
- ✅ IAM least privilege policies
- ✅ VPC network isolation
- ✅ Security groups and NACLs
- ✅ CloudTrail audit logging

### Monitoring & Alerting
- ✅ 8 CloudWatch alarms
- ✅ Email notifications (SNS)
- ✅ Custom log-based metrics
- ✅ DR readiness reporting
- ✅ Real-time health checks

### Cost Optimization
- ✅ Single-AZ RDS (not Multi-AZ)
- ✅ t3.micro instances
- ✅ S3 lifecycle policies
- ✅ Backup cold storage
- ✅ On-demand capacity (DynamoDB)

---

## 📦 Prerequisites

### Required Tools

1. **Terraform** (v1.0 or later)
   ```bash
   # Install on macOS
   brew install terraform
   
   # Install on Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Install on Windows
   choco install terraform
   ```

2. **AWS CLI** (v2 or later)
   ```bash
   # Install on macOS
   brew install awscli
   
   # Install on Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Install on Windows
   msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
   ```

3. **Python 3.8+** (for DR readiness script)
   ```bash
   # Install on macOS
   brew install python3
   
   # Install on Linux
   sudo apt-get update
   sudo apt-get install python3 python3-pip
   
   # Install on Windows
   # Download from https://www.python.org/downloads/
   ```

4. **Boto3** (AWS SDK for Python)
   ```bash
   pip install boto3 tabulate
   ```

### AWS Account Requirements

- **AWS Account** with administrative access
- **IAM Permissions**: Ability to create and manage:
  - VPC, Subnets, NAT Gateways, Internet Gateways
  - RDS instances and snapshots
  - S3 buckets and replication
  - DynamoDB tables and global tables
  - Lambda functions
  - CloudWatch alarms and logs
  - SNS topics and subscriptions
  - AWS Backup vaults and plans
  - KMS keys
  - IAM roles and policies

- **Service Limits**: Ensure adequate limits for:
  - VPCs: 10+ per region
  - Elastic IPs: 10+ per region
  - RDS instances: 40+ per region
  - S3 buckets: Unlimited

### AWS Credentials Configuration

```bash
# Configure AWS CLI
aws configure

# Enter your credentials:
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

---

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/aws-draas.git
cd aws-draas/drass-terraform
```

### 2. Configure Variables

Edit `terraform.tfvars`:

```hcl
# Project Configuration
project_name = "drass"
environment  = "prod"

# Region Configuration
primary_region = "us-east-1"
dr_region      = "us-west-2"

# Network Configuration
vpc_cidr = "10.0.0.0/16"

# RDS Configuration
db_instance_class  = "db.t3.micro"
db_engine_version  = "8.0.39"
db_username        = "admin"
db_password        = "YourSecurePassword123!"  # Change this!

# DynamoDB Configuration
dynamodb_table_name     = "drass-table"
dynamodb_read_capacity  = 5
dynamodb_write_capacity = 5

# Backup Configuration
backup_schedule        = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
backup_retention_days  = 35

# Monitoring Configuration
alert_email = "your-email@example.com"  # Change this!

# Tags
tags = {
  Project     = "DRaaS"
  Environment = "Production"
  ManagedBy   = "Terraform"
}
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review Plan

```bash
terraform plan
```

Expected output:
```
Plan: 110 to add, 0 to change, 0 to destroy.
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes approximately **15-20 minutes**.

### 6. Confirm SNS Subscription

Check your email for SNS subscription confirmation and click the link.

### 7. Verify Deployment

```bash
# Check Terraform outputs
terraform output

# Run DR readiness check
cd scripts
python dr_readiness_check.py
```

---

## ⚙️ Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_name` | Project identifier | `drass` |
| `environment` | Environment name | `prod` |
| `primary_region` | Primary AWS region | `us-east-1` |
| `dr_region` | DR AWS region | `us-west-2` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `db_username` | RDS master username | `admin` |
| `db_password` | RDS master password | `SecurePass123!` |
| `alert_email` | Email for alerts | `admin@example.com` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `db_instance_class` | RDS instance type | `db.t3.micro` |
| `db_engine_version` | MySQL version | `8.0.39` |
| `db_allocated_storage` | RDS storage (GB) | `20` |
| `backup_retention_days` | Primary backup retention | `35` |
| `backup_schedule` | Backup cron schedule | `cron(0 2 * * ? *)` |
| `dynamodb_read_capacity` | DynamoDB RCU | `5` |
| `dynamodb_write_capacity` | DynamoDB WCU | `5` |

### Environment-Specific Configurations

#### Development
```hcl
environment         = "dev"
db_instance_class   = "db.t3.micro"
backup_retention_days = 7
```

#### Staging
```hcl
environment         = "staging"
db_instance_class   = "db.t3.small"
backup_retention_days = 14
```

#### Production
```hcl
environment         = "prod"
db_instance_class   = "db.t3.medium"
backup_retention_days = 35
```

---

## 📊 Monitoring

### CloudWatch Alarms

| Alarm Name | Metric | Threshold | Action |
|------------|--------|-----------|--------|
| RDS Replica Lag | `ReplicaLag` | > 60 seconds | Email alert |
| RDS Replica Status | `DatabaseConnections` | < 1 | Email alert |
| S3 Replication | `ReplicationLatency` | > 3600 sec | Email alert |
| DynamoDB Replication | `ReplicationLatency` | > 60 sec | Email alert |
| Backup Failures | Custom metric | > 0 | Email alert |
| EC2 Snapshot Failures | Custom metric | > 0 | Email alert |
| Lambda Errors | `Errors` | > 0 | Email alert |
| DynamoDB Throttling | `UserErrors` | > 10 | Email alert |

### DR Readiness Check

Run the readiness check script to generate a health report:

```bash
cd scripts
python dr_readiness_check.py
```

Sample output:
```
================================================================================
                       DR READINESS REPORT
                       Generated: 2025-12-09 16:30:45 UTC
================================================================================

1. EC2 SNAPSHOT & REPLICATION STATUS
────────────────────────────────────────────────────────────────────────────
Status: ✓ HEALTHY
Total Instances: 0
Instances with Recent Snapshots: 0

2. RDS DR STATUS
────────────────────────────────────────────────────────────────────────────
Status: ✓ HEALTHY
Primary Instance: drass-prod-rds-primary (available)
DR Replica: drass-prod-rds-dr-replica (available)
Replication Lag: 0.5 seconds
Last Snapshot: 2025-12-09 02:15:33 (automated)

3. S3 CROSS-REGION REPLICATION STATUS
────────────────────────────────────────────────────────────────────────────
Status: ✓ HEALTHY
Primary Bucket: drass-prod-primary-d5e047cd
DR Bucket: drass-prod-primary-d5e047cd-dr-us-west-2
Replication Status: ENABLED

4. DYNAMODB GLOBAL TABLE SYNC STATUS
────────────────────────────────────────────────────────────────────────────
Status: ✓ HEALTHY
Table: drass-table
Primary Region Status: ACTIVE
DR Region Status: ACTIVE

5. AWS BACKUP JOB STATUS
────────────────────────────────────────────────────────────────────────────
Status: ! WARNING - No recent backup jobs found

6. CLOUDWATCH DR ALARM STATES
────────────────────────────────────────────────────────────────────────────
Total Alarms: 8
OK: 7
ALARM: 1 (drass-prod-rds-replica-status)
INSUFFICIENT_DATA: 0

7. OVERALL DR HEALTH SUMMARY
────────────────────────────────────────────────────────────────────────────
Overall Status: ✓ MOSTLY HEALTHY
RPO (Recovery Point Objective): ~1 minute
RTO (Recovery Time Objective): ~45-120 minutes
```

---

## 🔄 DR Operations

### Testing DR Failover

**⚠️ WARNING: Do NOT run in production without proper planning**

```bash
# 1. Test notification system
aws sns publish \
  --topic-arn $(terraform output -raw sns_topic_arn) \
  --subject "DR Test Alert" \
  --message "Testing DR notification system"

# 2. Simulate RDS failover (read-only test)
aws rds describe-db-instances \
  --db-instance-identifier $(terraform output -raw rds_replica_identifier) \
  --region us-west-2

# 3. Test Lambda failover function (dry-run mode)
aws lambda invoke \
  --function-name $(terraform output -raw failover_lambda_name) \
  --payload '{"dry_run": true}' \
  --region us-east-1 \
  response.json
```

### Performing Actual Failover

```bash
# 1. Verify DR region is healthy
cd scripts
python dr_readiness_check.py

# 2. Trigger failover Lambda
aws lambda invoke \
  --function-name drass-prod-failover \
  --region us-east-1 \
  response.json

# 3. Promote RDS read replica manually (if needed)
aws rds promote-read-replica \
  --db-instance-identifier drass-prod-rds-dr-replica \
  --region us-west-2

# 4. Update application to point to DR endpoints
# - Update RDS endpoint to DR replica
# - Update S3 bucket to DR bucket
# - DynamoDB automatically available in both regions

# 5. Verify failover
python dr_readiness_check.py
```

### Failback Procedures

```bash
# After primary region is restored:

# 1. Stop writes to DR region
# 2. Sync data from DR to primary
# 3. Recreate replication in reverse
# 4. Switch applications back to primary
# 5. Re-establish original DR setup

# Detailed steps in docs/FAILBACK.md
```

---

## 💰 Cost Estimation

### Monthly Cost Breakdown

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| **VPC & Networking** | | |
| NAT Gateways (6) | $32 each | **$192** |
| Elastic IPs (6) | $3.60 each | **$22** |
| Data Transfer | Varies | **$10** |
| **Compute & Database** | | |
| RDS MySQL (2 x t3.micro) | 2 instances | **$30** |
| RDS Storage (40 GB) | gp3 | **$4** |
| RDS Backups | Automated | **$2** |
| **Storage** | | |
| S3 Standard (10 GB) | 2 buckets | **$0.50** |
| S3 Replication | Data transfer | **$0.10** |
| DynamoDB (5 RCU/WCU) | Provisioned | **$3** |
| **Backup & DR** | | |
| AWS Backup Storage | 50 GB | **$5** |
| Cross-Region Copy | Cold storage | **$3** |
| **Serverless** | | |
| Lambda (EC2 + Failover) | Low usage | **$0.70** |
| **Monitoring** | | |
| CloudWatch Alarms (8) | $0.10 each | **$0.80** |
| CloudWatch Logs | 1 GB | **$1** |
| SNS | Email only | **$0.10** |
| **Security** | | |
| KMS Keys (2) | $1 each | **$2** |
| | **TOTAL** | **~$276/month** |

### Cost Optimization Tips

1. **Reduce NAT Gateways**: Use single NAT gateway instead of 3
   - **Savings**: ~$128/month
   - **Trade-off**: Lower availability

2. **Use VPC Endpoints**: For S3 and DynamoDB access
   - **Savings**: ~$10/month in data transfer
   - **Benefits**: No internet routing

3. **Reserved Instances**: For RDS (1-year commitment)
   - **Savings**: ~$10/month (35% discount)
   - **Trade-off**: Less flexibility

4. **DynamoDB On-Demand**: If usage is unpredictable
   - **Cost**: Pay per request
   - **Benefits**: No capacity planning

5. **S3 Intelligent-Tiering**: Automatic storage class transitions
   - **Savings**: ~$0.10/month
   - **Benefits**: Automated optimization

**Estimated Optimized Cost**: ~$138/month (50% reduction)

---

## 🐛 Troubleshooting

### Common Issues

#### Issue: Terraform Init Fails

```bash
Error: Failed to query available provider packages
```

**Solution:**
```bash
# Clear Terraform cache
rm -rf .terraform
rm .terraform.lock.hcl

# Re-initialize
terraform init
```

#### Issue: RDS Read Replica Creation Fails

```bash
Error: Error creating DB Instance: InvalidParameterValue
```

**Solution:**
```bash
# Ensure primary DB is available
aws rds describe-db-instances \
  --db-instance-identifier drass-prod-rds-primary \
  --query 'DBInstances[0].DBInstanceStatus'

# Wait for "available" status before creating replica
```

#### Issue: DynamoDB Global Table Error

```bash
Error: Unsupported operation: Customer Managed CMKs on Global Table Version 2017.11.29
```

**Solution:**
- Use AWS-managed encryption (default)
- Remove custom KMS key for DynamoDB
- This is a limitation of Global Tables v1

#### Issue: SNS Email Not Received

**Solution:**
```bash
# Check subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_topic_arn)

# Resend confirmation
aws sns subscribe \
  --topic-arn $(terraform output -raw sns_topic_arn) \
  --protocol email \
  --notification-endpoint your-email@example.com
```

#### Issue: Lambda Function Timeout

```bash
Error: Task timed out after 3.00 seconds
```

**Solution:**
- Increase Lambda timeout in `modules/lambda-*/main.tf`
- Check CloudWatch Logs for specific errors
- Verify IAM permissions

### Debugging Tools

```bash
# Check Terraform state
terraform show

# View specific resource
terraform state show module.rds_dr[0].aws_db_instance.primary

# Check AWS resources
aws rds describe-db-instances --region us-east-1
aws s3 ls
aws dynamodb list-tables --region us-east-1

# View Lambda logs
aws logs tail /aws/lambda/drass-prod-failover --follow

# Check CloudWatch alarms
aws cloudwatch describe-alarms --alarm-names drass-prod-rds-replica-lag
```

---

## 📚 Additional Documentation

- [Commands Reference](commands.md) - All CLI commands
- [Challenges & Solutions](challenges.md) - Problems encountered and fixes
- [Security Guide](security.md) - Security implementation details
- [API Reference](docs/API.md) - Terraform module APIs
- [Runbooks](docs/RUNBOOKS.md) - Operational procedures

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run Terraform validation
terraform fmt -recursive
terraform validate

# Run tests
cd tests
./run-tests.sh
```

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Authors

- **Your Name** - Initial work - [GitHub](https://github.com/yourusername)

---

## 🙏 Acknowledgments

- AWS Well-Architected Framework
- Terraform AWS Provider Documentation
- AWS Disaster Recovery Whitepaper
- Community contributors

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/aws-draas/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/aws-draas/discussions)
- **Email**: support@example.com

---

## 🔄 Changelog

### Version 1.0.0 (2025-12-09)
- Initial release
- Multi-region DRaaS implementation
- Automated replication for RDS, S3, DynamoDB
- CloudWatch monitoring and alerting
- Lambda-based failover automation
- DR readiness reporting script

---

**Built with ❤️ using Terraform and AWS**
