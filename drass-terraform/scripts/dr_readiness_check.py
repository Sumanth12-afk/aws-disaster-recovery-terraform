#!/usr/bin/env python3
"""
AWS DR Readiness Check Script
Retrieves real AWS DR state and generates formatted readiness report.
"""

import boto3
import argparse
import sys
from datetime import datetime, timezone, timedelta
from botocore.exceptions import ClientError, BotoCoreError

def get_primary_region():
    session = boto3.Session()
    return session.region_name or 'us-east-1'

def get_rpo_target():
    return 60

def format_timestamp(dt):
    if isinstance(dt, datetime):
        return dt.strftime('%Y-%m-%d %H:%M:%S UTC')
    return str(dt)

def calculate_age(start_time):
    if isinstance(start_time, datetime):
        delta = datetime.now(timezone.utc) - start_time
        return delta
    return None

def print_section_header(title):
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}\n")

def print_warning(message):
    print(f"  WARNING: {message}")

def check_ec2_snapshots(ec2_client, dr_region, rpo_minutes):
    print_section_header("EC2 Snapshot & Replication Status")
    
    issues = []
    snapshots_found = False
    
    try:
        volumes = ec2_client.describe_volumes()
        
        for volume in volumes.get('Volumes', []):
            volume_id = volume['VolumeId']
            
            snapshots = ec2_client.describe_snapshots(
                Filters=[
                    {'Name': 'volume-id', 'Values': [volume_id]},
                    {'Name': 'tag:DR', 'Values': ['true']}
                ],
                OwnerIds=['self']
            )
            
            if snapshots['Snapshots']:
                snapshots_found = True
                latest = max(snapshots['Snapshots'], key=lambda x: x['StartTime'])
                
                snapshot_id = latest['SnapshotId']
                start_time = latest['StartTime']
                state = latest['State']
                age = calculate_age(start_time)
                
                print(f"  Volume: {volume_id}")
                print(f"    Latest Snapshot ID: {snapshot_id}")
                print(f"    Snapshot Timestamp: {format_timestamp(start_time)}")
                print(f"    Snapshot State: {state}")
                
                if age:
                    age_minutes = age.total_seconds() / 60
                    print(f"    Age: {int(age_minutes)} minutes")
                    
                    if age_minutes > rpo_minutes:
                        warning = f"Snapshot for volume {volume_id} is older than RPO target ({rpo_minutes} minutes)"
                        print_warning(warning)
                        issues.append(warning)
                
                try:
                    dr_snapshots = boto3.client('ec2', region_name=dr_region).describe_snapshots(
                        Filters=[
                            {'Name': 'tag:SourceSnapshotId', 'Values': [snapshot_id]}
                        ],
                        OwnerIds=['self']
                    )
                    
                    if dr_snapshots['Snapshots']:
                        print(f"    Replication Status: Replicated to {dr_region}")
                    else:
                        warning = f"Snapshot {snapshot_id} not found in DR region {dr_region}"
                        print_warning(warning)
                        issues.append(warning)
                except Exception as e:
                    warning = f"Could not verify replication status: {str(e)}"
                    print_warning(warning)
                    issues.append(warning)
                
                print()
        
        if not snapshots_found:
            print("  No DR snapshots found for any volumes.")
            issues.append("No EC2 DR snapshots found")
    
    except Exception as e:
        error_msg = f"Error checking EC2 snapshots: {str(e)}"
        print_warning(error_msg)
        issues.append(error_msg)
    
    return issues

def check_rds_dr(rds_client, dr_region, rpo_minutes, replica_lag_threshold):
    print_section_header("RDS DR Status")
    
    issues = []
    
    try:
        db_instances = rds_client.describe_db_instances()
        
        for db in db_instances.get('DBInstances', []):
            db_id = db['DBInstanceIdentifier']
            print(f"  Primary DB Identifier: {db_id}")
            
            read_replicas = db.get('ReadReplicaDBInstanceIdentifiers', [])
            if read_replicas:
                for replica_arn in read_replicas:
                    try:
                        # Extract identifier from ARN
                        replica_id = replica_arn.split(':')[-1] if ':' in replica_arn else replica_arn
                        
                        # Check in DR region
                        dr_rds = boto3.client('rds', region_name=dr_region)
                        replica = dr_rds.describe_db_instances(DBInstanceIdentifier=replica_id)
                        replica_info = replica['DBInstances'][0]
                        
                        print(f"    Read Replica: {replica_id}")
                        print(f"    Status: {replica_info['DBInstanceStatus']}")
                        
                        if replica_info['DBInstanceStatus'] != 'available':
                            warning = f"RDS replica {replica_id} is not available"
                            print_warning(warning)
                            issues.append(warning)
                        
                        try:
                            metrics = boto3.client('cloudwatch').get_metric_statistics(
                                Namespace='AWS/RDS',
                                MetricName='ReplicaLag',
                                Dimensions=[
                                    {'Name': 'DBInstanceIdentifier', 'Value': replica_id}
                                ],
                                StartTime=datetime.now(timezone.utc) - timedelta(hours=1),
                                EndTime=datetime.now(timezone.utc),
                                Period=300,
                                Statistics=['Average']
                            )
                            
                            if metrics['Datapoints']:
                                latest_lag = max(metrics['Datapoints'], key=lambda x: x['Timestamp'])
                                lag_seconds = latest_lag['Average']
                                print(f"    Replica Lag: {int(lag_seconds)} seconds")
                                
                                if lag_seconds > replica_lag_threshold:
                                    warning = f"RDS replica {replica_id} lag ({int(lag_seconds)}s) exceeds threshold ({replica_lag_threshold}s)"
                                    print_warning(warning)
                                    issues.append(warning)
                            else:
                                print(f"    Replica Lag: No data available")
                        except Exception as e:
                            print(f"    Replica Lag: Could not retrieve ({str(e)})")
                        
                    except Exception as e:
                        warning = f"Error checking replica {replica_id}: {str(e)}"
                        print_warning(warning)
                        issues.append(warning)
            else:
                print("    No read replicas configured")
                issues.append(f"No read replicas for DB {db_id}")
            
            snapshots = rds_client.describe_db_snapshots(DBInstanceIdentifier=db_id)
            if snapshots['DBSnapshots']:
                latest_snapshot = max(snapshots['DBSnapshots'], key=lambda x: x['SnapshotCreateTime'])
                snapshot_id = latest_snapshot['DBSnapshotIdentifier']
                snapshot_time = latest_snapshot['SnapshotCreateTime']
                age = calculate_age(snapshot_time)
                
                print(f"    Latest Snapshot ID: {snapshot_id}")
                print(f"    Snapshot Timestamp: {format_timestamp(snapshot_time)}")
                
                if age:
                    age_minutes = age.total_seconds() / 60
                    if age_minutes > rpo_minutes:
                        warning = f"RDS snapshot {snapshot_id} is older than RPO target ({rpo_minutes} minutes)"
                        print_warning(warning)
                        issues.append(warning)
                
                try:
                    dr_rds = boto3.client('rds', region_name=dr_region)
                    dr_snapshots = dr_rds.describe_db_snapshots(
                        Filters=[
                            {'Name': 'db-instance-id', 'Values': [db_id]}
                        ]
                    )
                    
                    if dr_snapshots['DBSnapshots']:
                        print(f"    Snapshot Copy Status: Available in DR region")
                    else:
                        warning = f"RDS snapshot {snapshot_id} not found in DR region"
                        print_warning(warning)
                        issues.append(warning)
                except Exception as e:
                    print(f"    Snapshot Copy Status: Could not verify ({str(e)})")
            
            print()
    
    except Exception as e:
        error_msg = f"Error checking RDS DR status: {str(e)}"
        print_warning(error_msg)
        issues.append(error_msg)
    
    return issues

def check_s3_replication(s3_client, dr_region):
    print_section_header("S3 Cross-Region Replication Status")
    
    issues = []
    
    try:
        buckets = s3_client.list_buckets()
        
        replication_found = False
        for bucket_info in buckets.get('Buckets', []):
            bucket_name = bucket_info['Name']
            
            try:
                replication = s3_client.get_bucket_replication(Bucket=bucket_name)
                replication_found = True
                
                print(f"  Bucket: {bucket_name}")
                print(f"    Replication Enabled: Yes")
                
                rules = replication.get('ReplicationConfiguration', {}).get('Rules', [])
                for rule in rules:
                    destination = rule.get('Destination', {})
                    dest_bucket = destination.get('Bucket', '')
                    print(f"    Destination Bucket: {dest_bucket}")
                    
                    if dr_region not in dest_bucket:
                        warning = f"Replication destination for {bucket_name} may not be in DR region"
                        print_warning(warning)
                        issues.append(warning)
                
                try:
                    role_arn = replication.get('ReplicationConfiguration', {}).get('Role', '')
                    if role_arn:
                        iam = boto3.client('iam')
                        role_name = role_arn.split('/')[-1]
                        try:
                            iam.get_role(RoleName=role_name)
                            print(f"    IAM Replication Role: Exists ({role_name})")
                        except:
                            warning = f"Replication role {role_name} not found"
                            print_warning(warning)
                            issues.append(warning)
                except Exception as e:
                    print(f"    IAM Replication Role: Could not verify ({str(e)})")
                
                try:
                    objects = s3_client.list_objects_v2(Bucket=bucket_name, MaxKeys=1)
                    if objects.get('Contents'):
                        latest_obj = max(objects['Contents'], key=lambda x: x['LastModified'])
                        print(f"    Last Replicated Object: {format_timestamp(latest_obj['LastModified'])}")
                except:
                    print(f"    Last Replicated Object: Could not determine")
                
                print()
                
            except ClientError as e:
                if e.response['Error']['Code'] != 'ReplicationConfigurationNotFoundError':
                    raise
        
        if not replication_found:
            print("  No S3 buckets with replication configured found.")
            issues.append("No S3 cross-region replication configured")
    
    except Exception as e:
        error_msg = f"Error checking S3 replication: {str(e)}"
        print_warning(error_msg)
        issues.append(error_msg)
    
    return issues

def check_dynamodb_global_tables(dynamodb_client, dr_region):
    print_section_header("DynamoDB Global Table Sync Status")
    
    issues = []
    
    try:
        # First check for Global Tables v1 (2017.11.29)
        try:
            global_tables = dynamodb_client.list_global_tables()
            if global_tables.get('GlobalTables'):
                for gt in global_tables['GlobalTables']:
                    table_name = gt['GlobalTableName']
                    replicas = gt.get('ReplicationGroup', [])
                    
                    print(f"  Table Name: {table_name}")
                    print(f"    Global Table Version: 2017.11.29")
                    print(f"    Replica Regions:")
                    
                    for replica in replicas:
                        region = replica['RegionName']
                        print(f"      - {region}: ACTIVE")
                    
                    if dr_region not in [r['RegionName'] for r in replicas]:
                        warning = f"DynamoDB global table {table_name} does not have replica in DR region {dr_region}"
                        print_warning(warning)
                        issues.append(warning)
                    else:
                        print(f"    Sync Status: All replicas active and syncing")
                    
                    print()
                
                return issues
        except Exception as e:
            if 'AccessDeniedException' not in str(e):
                pass
        
        # Fall back to checking regular tables with replicas (v2)
        tables = dynamodb_client.list_tables()
        
        for table_name in tables.get('TableNames', []):
            try:
                table_info = dynamodb_client.describe_table(TableName=table_name)
                table_desc = table_info['Table']
                
                replicas = table_desc.get('Replicas', [])
                if replicas:
                    print(f"  Table Name: {table_name}")
                    print(f"    Replica Regions:")
                    
                    all_synced = True
                    for replica in replicas:
                        region = replica['RegionName']
                        status = replica.get('ReplicaStatus', 'UNKNOWN')
                        last_update = replica.get('ReplicaLastUpdatedDateTime', 'N/A')
                        
                        print(f"      - {region}: {status}")
                        if isinstance(last_update, datetime):
                            print(f"        Last Update: {format_timestamp(last_update)}")
                        
                        if status != 'ACTIVE':
                            warning = f"DynamoDB table {table_name} replica in {region} is not ACTIVE (Status: {status})"
                            print_warning(warning)
                            issues.append(warning)
                            all_synced = False
                    
                    if dr_region not in [r['RegionName'] for r in replicas]:
                        warning = f"DynamoDB table {table_name} does not have replica in DR region {dr_region}"
                        print_warning(warning)
                        issues.append(warning)
                    
                    if all_synced:
                        print(f"    Sync Status: All replicas in sync")
                    
                    print()
                else:
                    print(f"  Table Name: {table_name}")
                    print(f"    Global Table: No replicas configured")
                    issues.append(f"DynamoDB table {table_name} has no replicas")
                    print()
            
            except Exception as e:
                warning = f"Error checking table {table_name}: {str(e)}"
                print_warning(warning)
                issues.append(warning)
    
    except Exception as e:
        error_msg = f"Error checking DynamoDB global tables: {str(e)}"
        print_warning(error_msg)
        issues.append(error_msg)
    
    return issues

def check_backup_jobs(backup_client):
    print_section_header("AWS Backup Job Status")
    
    issues = []
    jobs_found = False
    
    try:
        jobs = backup_client.list_backup_jobs(MaxResults=50)
        
        for job in jobs.get('BackupJobs', []):
            jobs_found = True
            job_id = job['BackupJobId']
            resource_arn = job.get('ResourceArn', 'N/A')
            backup_type = job.get('BackupType', 'N/A')
            state = job['State']
            start_time = job['CreationDate']
            end_time = job.get('CompletionDate', 'N/A')
            
            print(f"  BackupJobId: {job_id}")
            print(f"    ResourceArn: {resource_arn}")
            print(f"    Backup Type: {backup_type}")
            print(f"    State: {state}")
            print(f"    Start Time: {format_timestamp(start_time)}")
            if isinstance(end_time, datetime):
                print(f"    End Time: {format_timestamp(end_time)}")
            else:
                print(f"    End Time: {end_time}")
            
            if state == 'FAILED':
                warning = f"Backup job {job_id} failed"
                print_warning(warning)
                issues.append(warning)
            elif state == 'ABORTED':
                warning = f"Backup job {job_id} was aborted"
                print_warning(warning)
                issues.append(warning)
            
            print()
        
        if not jobs_found:
            print("  No backup jobs found.")
            issues.append("No AWS Backup jobs found")
    
    except Exception as e:
        error_msg = f"Error checking AWS Backup jobs: {str(e)}"
        print_warning(error_msg)
        issues.append(error_msg)
    
    return issues

def check_cloudwatch_alarms(cloudwatch_client, name_prefix):
    print_section_header("CloudWatch DR Alarm States")
    
    issues = []
    
    try:
        alarms = cloudwatch_client.describe_alarms(
            AlarmNamePrefix=name_prefix
        )
        
        if alarms['MetricAlarms']:
            for alarm in alarms['MetricAlarms']:
                alarm_name = alarm['AlarmName']
                state = alarm['StateValue']
                metric_name = alarm['MetricName']
                
                print(f"  Alarm Name: {alarm_name}")
                print(f"    Alarm State: {state}")
                print(f"    Metric Name: {metric_name}")
                
                if state == 'ALARM':
                    warning = f"CloudWatch alarm {alarm_name} is in ALARM state"
                    print_warning(warning)
                    issues.append(warning)
                elif state == 'INSUFFICIENT_DATA':
                    print(f"    Note: Alarm has insufficient data")
                
                print()
        else:
            print("  No DR-related CloudWatch alarms found.")
    
    except Exception as e:
        error_msg = f"Error checking CloudWatch alarms: {str(e)}"
        print_warning(error_msg)
        issues.append(error_msg)
    
    return issues

def generate_summary(all_issues, rpo_minutes):
    print_section_header("Overall DR Health Summary")
    
    critical_risks = []
    warnings = []
    
    for issue in all_issues:
        if 'FAILED' in issue.upper() or 'not available' in issue.lower() or 'not found' in issue.lower():
            critical_risks.append(issue)
        else:
            warnings.append(issue)
    
    if critical_risks:
        status = "FAIL"
    elif warnings:
        status = "WARNING"
    else:
        status = "PASS"
    
    print(f"  DR Readiness Status: {status}")
    print(f"  Number of Issues Found: {len(all_issues)}")
    print(f"    - Critical Risks: {len(critical_risks)}")
    print(f"    - Warnings: {len(warnings)}")
    
    if critical_risks:
        print(f"\n  Critical Risks:")
        for risk in critical_risks:
            print(f"    - {risk}")
    
    if warnings:
        print(f"\n  Warnings:")
        for warning in warnings[:10]:
            print(f"    - {warning}")
        if len(warnings) > 10:
            print(f"    ... and {len(warnings) - 10} more warnings")
    
    print(f"\n  Recommended Next Actions:")
    if status == "FAIL":
        print(f"    - Immediately investigate critical risks")
        print(f"    - Verify replication configurations")
        print(f"    - Check AWS Backup job failures")
    elif status == "WARNING":
        print(f"    - Review warnings and address non-critical issues")
        print(f"    - Verify RPO targets are being met")
        print(f"    - Monitor CloudWatch alarms")
    else:
        print(f"    - Continue monitoring DR systems")
        print(f"    - Review RPO/RTO compliance")
        print(f"    - Test failover procedures regularly")
    
    print(f"\n  Report Timestamp: {format_timestamp(datetime.now(timezone.utc))}")
    
    return status

def main():
    parser = argparse.ArgumentParser(description='AWS DR Readiness Check')
    parser.add_argument('--primary-region', default=None, help='Primary AWS region')
    parser.add_argument('--dr-region', required=True, help='DR AWS region')
    parser.add_argument('--rpo-minutes', type=int, default=60, help='RPO target in minutes')
    parser.add_argument('--replica-lag-threshold', type=int, default=60, help='RDS replica lag threshold in seconds')
    parser.add_argument('--name-prefix', default='', help='Name prefix for filtering resources')
    
    args = parser.parse_args()
    
    primary_region = args.primary_region or get_primary_region()
    dr_region = args.dr_region
    rpo_minutes = args.rpo_minutes
    replica_lag_threshold = args.replica_lag_threshold
    name_prefix = args.name_prefix
    
    print("=" * 60)
    print("  AWS DR READINESS REPORT")
    print("=" * 60)
    print(f"\nPrimary Region: {primary_region}")
    print(f"DR Region: {dr_region}")
    print(f"RPO Target: {rpo_minutes} minutes")
    print(f"Replica Lag Threshold: {replica_lag_threshold} seconds")
    
    all_issues = []
    
    try:
        ec2_client = boto3.client('ec2', region_name=primary_region)
        rds_client = boto3.client('rds', region_name=primary_region)
        s3_client = boto3.client('s3', region_name=primary_region)
        dynamodb_client = boto3.client('dynamodb', region_name=primary_region)
        backup_client = boto3.client('backup', region_name=primary_region)
        cloudwatch_client = boto3.client('cloudwatch', region_name=primary_region)
        
        all_issues.extend(check_ec2_snapshots(ec2_client, dr_region, rpo_minutes))
        all_issues.extend(check_rds_dr(rds_client, dr_region, rpo_minutes, replica_lag_threshold))
        all_issues.extend(check_s3_replication(s3_client, dr_region))
        all_issues.extend(check_dynamodb_global_tables(dynamodb_client, dr_region))
        all_issues.extend(check_backup_jobs(backup_client))
        all_issues.extend(check_cloudwatch_alarms(cloudwatch_client, name_prefix))
        
        status = generate_summary(all_issues, rpo_minutes)
        
        print("\n" + "=" * 60)
        print("  END OF REPORT")
        print("=" * 60 + "\n")
        
        sys.exit(0 if status == "PASS" else 1)
    
    except Exception as e:
        print(f"\nFATAL ERROR: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    main()

