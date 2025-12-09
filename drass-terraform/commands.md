# DRaaS Commands Reference

Complete command reference for deploying, managing, and operating the AWS DRaaS solution.

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Terraform Commands](#terraform-commands)
- [AWS CLI Commands](#aws-cli-commands)
- [DR Operations](#dr-operations)
- [Monitoring & Debugging](#monitoring--debugging)
- [Backup & Restore](#backup--restore)
- [Security Operations](#security-operations)
- [Cleanup](#cleanup)

---

## 🔧 Prerequisites

### Install Required Tools

#### Terraform
```bash
# macOS
brew install terraform

# Linux (Ubuntu/Debian)
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform --version

# Windows (PowerShell)
choco install terraform

# Verify installation
terraform version
```

#### AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Windows
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

# Verify installation
aws --version
```

#### Python & Dependencies
```bash
# Install Python 3.8+
python3 --version

# Install Boto3 and dependencies
pip3 install boto3 tabulate

# Verify installation
python3 -c "import boto3; print(boto3.__version__)"
```

### Configure AWS Credentials

```bash
# Interactive configuration
aws configure

# Manual configuration
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"

# Verify configuration
aws sts get-caller-identity

# Output:
# {
#   "UserId": "AIDAI...",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/your-user"
# }
```

---

## 🏗️ Terraform Commands

### Initial Setup

```bash
# Navigate to Terraform directory
cd drass-terraform

# Initialize Terraform (downloads providers)
terraform init

# Expected output:
# Initializing modules...
# Initializing the backend...
# Initializing provider plugins...
# Terraform has been successfully initialized!

# Validate configuration syntax
terraform validate

# Format Terraform files
terraform fmt -recursive

# Check formatting without changes
terraform fmt -check -recursive
```

### Planning & Deployment

```bash
# Generate execution plan
terraform plan

# Save plan to file
terraform plan -out=tfplan

# Show detailed plan
terraform plan -no-color | tee plan.txt

# Apply changes (with confirmation)
terraform apply

# Apply without confirmation
terraform apply -auto-approve

# Apply specific plan file
terraform apply tfplan

# Apply with variable overrides
terraform apply -var="environment=staging" -var="db_instance_class=db.t3.small"

# Apply with var file
terraform apply -var-file="staging.tfvars"
```

### State Management

```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show module.rds_dr[0].aws_db_instance.primary

# Show all state details
terraform show

# Show outputs
terraform output

# Show specific output
terraform output -raw rds_primary_endpoint

# Show outputs in JSON
terraform output -json

# Refresh state without modifying infrastructure
terraform refresh

# Import existing AWS resource
terraform import module.vpc_primary.aws_vpc.main vpc-12345678
```

### Resource Targeting

```bash
# Plan for specific resource
terraform plan -target=module.rds_dr

# Apply changes to specific resource only
terraform apply -target=module.rds_dr[0].aws_db_instance.primary

# Destroy specific resource
terraform destroy -target=module.monitoring.aws_cloudwatch_metric_alarm.rds_replica_lag[0]
```

### Workspace Management

```bash
# List workspaces
terraform workspace list

# Create new workspace
terraform workspace new staging

# Switch workspace
terraform workspace select production

# Show current workspace
terraform workspace show

# Delete workspace
terraform workspace delete staging
```

### Troubleshooting & Debugging

```bash
# Enable detailed logging
export TF_LOG=DEBUG
terraform apply

# Log to file
export TF_LOG=TRACE
export TF_LOG_PATH=./terraform.log
terraform apply

# Disable logging
unset TF_LOG
unset TF_LOG_PATH

# Taint resource (mark for recreation)
terraform taint module.rds_dr[0].aws_db_instance.primary

# Untaint resource
terraform untaint module.rds_dr[0].aws_db_instance.primary

# Force unlock state (if locked)
terraform force-unlock <LOCK_ID>

# Get provider schema
terraform providers schema -json > schema.json
```

---

## ☁️ AWS CLI Commands

### RDS Operations

```bash
# List all RDS instances
aws rds describe-db-instances

# Get specific RDS instance details
aws rds describe-db-instances \
  --db-instance-identifier drass-prod-rds-primary \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' \
  --output table

# Check RDS replica status
aws rds describe-db-instances \
  --db-instance-identifier drass-prod-rds-dr-replica \
  --region us-west-2

# List RDS snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier drass-prod-rds-primary \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
  --output table

# Create manual snapshot
aws rds create-db-snapshot \
  --db-snapshot-identifier drass-manual-snapshot-$(date +%Y%m%d) \
  --db-instance-identifier drass-prod-rds-primary

# Promote read replica to standalone
aws rds promote-read-replica \
  --db-instance-identifier drass-prod-rds-dr-replica \
  --region us-west-2

# Reboot RDS instance
aws rds reboot-db-instance \
  --db-instance-identifier drass-prod-rds-primary

# Modify RDS instance
aws rds modify-db-instance \
  --db-instance-identifier drass-prod-rds-primary \
  --db-instance-class db.t3.small \
  --apply-immediately
```

### S3 Operations

```bash
# List all buckets
aws s3 ls

# List bucket contents
aws s3 ls s3://drass-prod-primary-d5e047cd/

# Get bucket replication status
aws s3api get-bucket-replication \
  --bucket drass-prod-primary-d5e047cd

# Get bucket versioning
aws s3api get-bucket-versioning \
  --bucket drass-prod-primary-d5e047cd

# Upload file
aws s3 cp test-file.txt s3://drass-prod-primary-d5e047cd/

# Download file
aws s3 cp s3://drass-prod-primary-d5e047cd/test-file.txt ./

# Sync directory
aws s3 sync ./local-dir s3://drass-prod-primary-d5e047cd/remote-dir/

# Get object metadata
aws s3api head-object \
  --bucket drass-prod-primary-d5e047cd \
  --key test-file.txt

# List object versions
aws s3api list-object-versions \
  --bucket drass-prod-primary-d5e047cd \
  --prefix test-file.txt

# Check replication metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name ReplicationLatency \
  --dimensions Name=SourceBucket,Value=drass-prod-primary-d5e047cd \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### DynamoDB Operations

```bash
# List tables
aws dynamodb list-tables

# Describe table
aws dynamodb describe-table \
  --table-name drass-table

# Get table in DR region
aws dynamodb describe-table \
  --table-name drass-table \
  --region us-west-2

# Describe global table
aws dynamodb describe-global-table \
  --global-table-name drass-table

# Put item
aws dynamodb put-item \
  --table-name drass-table \
  --item '{"id":{"S":"test-123"},"data":{"S":"test data"}}'

# Get item
aws dynamodb get-item \
  --table-name drass-table \
  --key '{"id":{"S":"test-123"}}'

# Scan table
aws dynamodb scan \
  --table-name drass-table \
  --limit 10

# Query table
aws dynamodb query \
  --table-name drass-table \
  --key-condition-expression "id = :id" \
  --expression-attribute-values '{":id":{"S":"test-123"}}'

# Get table metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ReplicationLatency \
  --dimensions Name=TableName,Value=drass-table Name=ReceivingRegion,Value=us-west-2 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Lambda Operations

```bash
# List Lambda functions
aws lambda list-functions \
  --query 'Functions[*].[FunctionName,Runtime,LastModified]' \
  --output table

# Get function details
aws lambda get-function \
  --function-name drass-prod-failover

# Invoke Lambda function
aws lambda invoke \
  --function-name drass-prod-failover \
  --payload '{"test": true}' \
  response.json

# View response
cat response.json

# Invoke EC2 snapshot Lambda
aws lambda invoke \
  --function-name drass-prod-ec2-snapshot \
  response.json

# Get Lambda configuration
aws lambda get-function-configuration \
  --function-name drass-prod-failover

# Update Lambda code (from zip)
aws lambda update-function-code \
  --function-name drass-prod-failover \
  --zip-file fileb://lambda.zip

# Update environment variables
aws lambda update-function-configuration \
  --function-name drass-prod-failover \
  --environment Variables="{KEY=value}"
```

### CloudWatch Operations

```bash
# List alarms
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table

# Get specific alarm
aws cloudwatch describe-alarms \
  --alarm-names drass-prod-rds-replica-lag

# Get alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name drass-prod-rds-replica-lag \
  --max-records 10

# Set alarm state (for testing)
aws cloudwatch set-alarm-state \
  --alarm-name drass-prod-rds-replica-lag \
  --state-value ALARM \
  --state-reason "Testing alarm"

# Get metric statistics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=drass-prod-rds-dr-replica \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# View Lambda logs
aws logs tail /aws/lambda/drass-prod-failover --follow

# View specific log stream
aws logs get-log-events \
  --log-group-name /aws/lambda/drass-prod-failover \
  --log-stream-name '2025/12/09/[$LATEST]abc123'

# Create log insights query
aws logs start-query \
  --log-group-name /aws/lambda/drass-prod-failover \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc'
```

### SNS Operations

```bash
# List SNS topics
aws sns list-topics

# Get topic details
aws sns get-topic-attributes \
  --topic-arn arn:aws:sns:us-east-1:123456789012:drass-prod-dr-alerts

# List subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:123456789012:drass-prod-dr-alerts

# Send test notification
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:123456789012:drass-prod-dr-alerts \
  --subject "DR Test Alert" \
  --message "This is a test notification from DRaaS system"

# Subscribe email to topic
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:drass-prod-dr-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Unsubscribe
aws sns unsubscribe \
  --subscription-arn arn:aws:sns:us-east-1:123456789012:drass-prod-dr-alerts:abc-123
```

### AWS Backup Operations

```bash
# List backup vaults
aws backup list-backup-vaults

# List backup plans
aws backup list-backup-plans

# Get backup plan details
aws backup get-backup-plan \
  --backup-plan-id e260a8ec-300e-4e2d-9d1b-1779c8ed1555

# List recovery points (backups)
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name drass-prod-backup-vault

# List backup jobs
aws backup list-backup-jobs \
  --by-backup-vault-name drass-prod-backup-vault

# Get backup job details
aws backup describe-backup-job \
  --backup-job-id 12345678-1234-1234-1234-123456789012

# Start on-demand backup
aws backup start-backup-job \
  --backup-vault-name drass-prod-backup-vault \
  --resource-arn arn:aws:rds:us-east-1:123456789012:db:drass-prod-rds-primary \
  --iam-role-arn arn:aws:iam::123456789012:role/drass-prod-backup-role

# List restore jobs
aws backup list-restore-jobs
```

---

## 🔄 DR Operations

### DR Readiness Check

```bash
# Navigate to scripts directory
cd scripts

# Run DR readiness check
python3 dr_readiness_check.py

# Save report to file
python3 dr_readiness_check.py > dr-report-$(date +%Y%m%d).txt

# Run with specific AWS profile
AWS_PROFILE=production python3 dr_readiness_check.py

# Schedule daily readiness check (crontab)
# Run at 8 AM daily
0 8 * * * cd /path/to/scripts && python3 dr_readiness_check.py | mail -s "DR Readiness Report" admin@example.com
```

### Test DR Notifications

```bash
# Get SNS topic ARN from Terraform
SNS_TOPIC=$(terraform output -raw sns_topic_arn)

# Send test notification
aws sns publish \
  --topic-arn $SNS_TOPIC \
  --subject "DR System Test" \
  --message "Testing DR notification system - $(date)"

# Send multiple test notifications
for alert_type in "RDS_FAILURE" "S3_REPLICATION_DELAY" "BACKUP_FAILURE"; do
  aws sns publish \
    --topic-arn $SNS_TOPIC \
    --subject "Test Alert: $alert_type" \
    --message "Simulating $alert_type event at $(date)"
  sleep 2
done
```

### RDS Failover Operations

```bash
# Check replica status before failover
aws rds describe-db-instances \
  --db-instance-identifier drass-prod-rds-dr-replica \
  --region us-west-2 \
  --query 'DBInstances[0].StatusInfos'

# Check replication lag
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=drass-prod-rds-dr-replica \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --region us-west-2

# Promote read replica (FAILOVER)
aws rds promote-read-replica \
  --db-instance-identifier drass-prod-rds-dr-replica \
  --backup-retention-period 7 \
  --region us-west-2

# Monitor promotion progress
watch -n 10 'aws rds describe-db-instances \
  --db-instance-identifier drass-prod-rds-dr-replica \
  --region us-west-2 \
  --query "DBInstances[0].[DBInstanceStatus,ReadReplicaSourceDBInstanceIdentifier]"'

# After promotion, update application endpoints
# Primary endpoint (OLD): drass-prod-rds-primary.xxx.us-east-1.rds.amazonaws.com
# DR endpoint (NEW): drass-prod-rds-dr-replica.xxx.us-west-2.rds.amazonaws.com
```

### S3 Failover Operations

```bash
# Check replication status
aws s3api get-bucket-replication \
  --bucket drass-prod-primary-d5e047cd

# Verify DR bucket has data
aws s3 ls s3://drass-prod-primary-d5e047cd-dr-us-west-2/ --recursive

# Compare object counts
PRIMARY_COUNT=$(aws s3 ls s3://drass-prod-primary-d5e047cd/ --recursive | wc -l)
DR_COUNT=$(aws s3 ls s3://drass-prod-primary-d5e047cd-dr-us-west-2/ --recursive | wc -l)
echo "Primary: $PRIMARY_COUNT, DR: $DR_COUNT"

# Failover: Update application to use DR bucket
# Update S3 endpoint from:
#   drass-prod-primary-d5e047cd.s3.us-east-1.amazonaws.com
# To:
#   drass-prod-primary-d5e047cd-dr-us-west-2.s3.us-west-2.amazonaws.com
```

### Lambda-Based Automated Failover

```bash
# Invoke failover Lambda
aws lambda invoke \
  --function-name drass-prod-failover \
  --region us-east-1 \
  --payload '{"trigger": "manual", "reason": "DR drill"}' \
  response.json

# View response
cat response.json

# Monitor Lambda execution
aws logs tail /aws/lambda/drass-prod-failover --follow

# Check failover completion
python3 dr_readiness_check.py
```

---

## 📊 Monitoring & Debugging

### Real-Time Monitoring

```bash
# Monitor all CloudWatch alarms
watch -n 30 'aws cloudwatch describe-alarms \
  --query "MetricAlarms[?starts_with(AlarmName, \`drass-prod\`)].{Name:AlarmName,State:StateValue,Reason:StateReason}" \
  --output table'

# Monitor RDS replica lag
watch -n 10 'aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=drass-prod-rds-dr-replica \
  --start-time $(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --region us-west-2 \
  --query "Datapoints[-1].Average"'

# Monitor Lambda errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/drass-prod-failover \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '1 hour ago' +%s000) \
  --query 'events[*].[timestamp,message]' \
  --output text
```

### Health Checks

```bash
# Check RDS health
aws rds describe-db-instances \
  --query 'DBInstances[?starts_with(DBInstanceIdentifier, `drass-prod`)].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,AZ:AvailabilityZone}' \
  --output table

# Check S3 bucket health
for bucket in $(aws s3 ls | grep drass-prod | awk '{print $3}'); do
  echo "Bucket: $bucket"
  aws s3api get-bucket-versioning --bucket $bucket
  aws s3api get-bucket-replication --bucket $bucket 2>/dev/null || echo "No replication configured"
  echo "---"
done

# Check DynamoDB table health
aws dynamodb describe-table \
  --table-name drass-table \
  --query '{Name:Table.TableName,Status:Table.TableStatus,ItemCount:Table.ItemCount,SizeBytes:Table.TableSizeBytes}'

# Check Lambda function health
aws lambda list-functions \
  --query 'Functions[?starts_with(FunctionName, `drass-prod`)].{Name:FunctionName,Runtime:Runtime,LastModified:LastModified}' \
  --output table
```

### Log Analysis

```bash
# Search Lambda logs for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/drass-prod-ec2-snapshot \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '24 hours ago' +%s000)

# Get recent Lambda invocations
aws logs describe-log-streams \
  --log-group-name /aws/lambda/drass-prod-failover \
  --order-by LastEventTime \
  --descending \
  --max-items 5

# Export logs to file
aws logs filter-log-events \
  --log-group-name /aws/lambda/drass-prod-failover \
  --start-time $(date -u -d '24 hours ago' +%s000) \
  --output text > lambda-logs-$(date +%Y%m%d).txt

# Search CloudWatch Logs Insights
aws logs start-query \
  --log-group-name /aws/lambda/drass-prod-failover \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20'
```

---

## 💾 Backup & Restore

### Manual Backups

```bash
# Create RDS snapshot
aws rds create-db-snapshot \
  --db-snapshot-identifier drass-manual-$(date +%Y%m%d-%H%M%S) \
  --db-instance-identifier drass-prod-rds-primary

# Copy snapshot to DR region
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:us-east-1:123456789012:snapshot:drass-manual-20251209 \
  --target-db-snapshot-identifier drass-manual-20251209-dr \
  --region us-west-2

# Create DynamoDB backup
aws dynamodb create-backup \
  --table-name drass-table \
  --backup-name drass-dynamodb-backup-$(date +%Y%m%d)

# Trigger AWS Backup job
aws backup start-backup-job \
  --backup-vault-name drass-prod-backup-vault \
  --resource-arn arn:aws:rds:us-east-1:123456789012:db:drass-prod-rds-primary \
  --iam-role-arn $(terraform output -raw backup_role_arn) \
  --start-window-minutes 60 \
  --complete-window-minutes 120
```

### Restore Operations

```bash
# Restore RDS from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier drass-restored-$(date +%Y%m%d) \
  --db-snapshot-identifier drass-manual-20251209 \
  --db-instance-class db.t3.micro \
  --vpc-security-group-ids sg-xxxxxxxxx

# Restore DynamoDB from backup
aws dynamodb restore-table-from-backup \
  --target-table-name drass-table-restored \
  --backup-arn arn:aws:dynamodb:us-east-1:123456789012:table/drass-table/backup/01234567890123

# Restore from AWS Backup
aws backup start-restore-job \
  --recovery-point-arn arn:aws:backup:us-east-1:123456789012:recovery-point:abc-123 \
  --iam-role-arn $(terraform output -raw backup_role_arn) \
  --metadata '{"DBInstanceClass":"db.t3.micro"}'

# Monitor restore progress
aws rds describe-db-instances \
  --db-instance-identifier drass-restored-20251209 \
  --query 'DBInstances[0].[DBInstanceStatus,PercentProgress]'
```

---

## 🔐 Security Operations

### KMS Operations

```bash
# List KMS keys
aws kms list-keys

# Get key details
aws kms describe-key \
  --key-id $(terraform output -raw kms_key_id)

# List key aliases
aws kms list-aliases \
  --query 'Aliases[?starts_with(AliasName, `alias/drass`)].{Alias:AliasName,KeyId:TargetKeyId}'

# Enable key rotation
aws kms enable-key-rotation \
  --key-id $(terraform output -raw kms_key_id)

# Get key rotation status
aws kms get-key-rotation-status \
  --key-id $(terraform output -raw kms_key_id)
```

### IAM Operations

```bash
# List IAM roles for DRaaS
aws iam list-roles \
  --query 'Roles[?starts_with(RoleName, `drass-prod`)].{Name:RoleName,CreatedDate:CreateDate}'

# Get role details
aws iam get-role \
  --role-name drass-prod-lambda-failover-role

# List attached policies
aws iam list-attached-role-policies \
  --role-name drass-prod-lambda-failover-role

# Get policy document
aws iam get-role-policy \
  --role-name drass-prod-lambda-failover-role \
  --policy-name drass-prod-lambda-failover-policy
```

### Security Group Auditing

```bash
# List security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=drass" \
  --query 'SecurityGroups[*].{ID:GroupId,Name:GroupName,VPC:VpcId}' \
  --output table

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw rds_primary_security_group_id) \
  --query 'SecurityGroups[0].IpPermissions'

# Find overly permissive rules (0.0.0.0/0)
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=drass" \
  --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].{ID:GroupId,Name:GroupName}'
```

---

## 🗑️ Cleanup

### Destroy Infrastructure

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy with confirmation
terraform destroy

# Destroy without confirmation (USE WITH CAUTION!)
terraform destroy -auto-approve

# Destroy specific resource
terraform destroy -target=module.monitoring

# Destroy and save plan
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

### Manual Cleanup (if Terraform fails)

```bash
# Delete RDS instances
aws rds delete-db-instance \
  --db-instance-identifier drass-prod-rds-dr-replica \
  --skip-final-snapshot \
  --region us-west-2

aws rds delete-db-instance \
  --db-instance-identifier drass-prod-rds-primary \
  --skip-final-snapshot

# Delete S3 buckets (must be empty first)
aws s3 rm s3://drass-prod-primary-d5e047cd --recursive
aws s3 rb s3://drass-prod-primary-d5e047cd

aws s3 rm s3://drass-prod-primary-d5e047cd-dr-us-west-2 --recursive --region us-west-2
aws s3 rb s3://drass-prod-primary-d5e047cd-dr-us-west-2 --region us-west-2

# Delete DynamoDB global table
aws dynamodb delete-table --table-name drass-table
aws dynamodb delete-table --table-name drass-table --region us-west-2

# Delete Lambda functions
aws lambda delete-function --function-name drass-prod-ec2-snapshot
aws lambda delete-function --function-name drass-prod-failover

# Delete CloudWatch alarms
aws cloudwatch delete-alarms --alarm-names \
  drass-prod-rds-replica-lag \
  drass-prod-rds-replica-status \
  drass-prod-s3-replication-failure

# Delete SNS topic
aws sns delete-topic --topic-arn arn:aws:sns:us-east-1:123456789012:drass-prod-dr-alerts

# Delete VPCs
aws ec2 delete-vpc --vpc-id vpc-xxxxxxxxx
aws ec2 delete-vpc --vpc-id vpc-yyyyyyyyy --region us-west-2
```

### Cleanup State Files

```bash
# Remove state files (LOCAL ONLY - use with caution)
rm -rf .terraform
rm .terraform.lock.hcl
rm terraform.tfstate
rm terraform.tfstate.backup

# Remove plan files
rm tfplan destroy.tfplan

# Clean up logs
rm terraform.log
rm *.log
```

---

## 📝 Quick Reference Commands

```bash
# Deploy
terraform init && terraform apply -auto-approve

# Check DR health
cd scripts && python3 dr_readiness_check.py

# Send test alert
aws sns publish --topic-arn $(terraform output -raw sns_topic_arn) --subject "Test" --message "Test alert"

# Check RDS status
aws rds describe-db-instances --query 'DBInstances[?starts_with(DBInstanceIdentifier, `drass`)].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}' --output table

# View Lambda logs
aws logs tail /aws/lambda/drass-prod-failover --follow

# Destroy
terraform destroy -auto-approve
```

---

**For more detailed information, see [README.md](README.md) and [challenges.md](challenges.md)**

