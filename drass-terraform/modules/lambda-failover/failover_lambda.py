import boto3
import json
import os
from datetime import datetime, timezone

ec2 = boto3.client('ec2')
rds = boto3.client('rds')
dynamodb = boto3.client('dynamodb')
s3 = boto3.client('s3')
backup = boto3.client('backup')
sns = boto3.client('sns')

def handler(event, context):
    dr_region = os.environ['DR_REGION']
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    rto_target = int(os.environ['RTO_TARGET'])
    
    results = {
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'actions_taken': [],
        'errors': []
    }
    
    try:
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject='DR Failover Initiated',
            Message=f'DR failover process started at {results["timestamp"]}'
        )
        
        rds_instances = rds.describe_db_instances()
        for db in rds_instances['DBInstances']:
            if db.get('ReadReplicaDBInstanceIdentifiers'):
                for replica_id in db['ReadReplicaDBInstanceIdentifiers']:
                    try:
                        replica = rds.describe_db_instances(DBInstanceIdentifier=replica_id)
                        if replica['DBInstances'][0]['DBInstanceStatus'] == 'available':
                            rds.promote_read_replica(DBInstanceIdentifier=replica_id)
                            results['actions_taken'].append(f'Promoted RDS replica: {replica_id}')
                    except Exception as e:
                        results['errors'].append(f'Error promoting RDS replica {replica_id}: {str(e)}')
        
        ec2_instances = ec2.describe_instances(
            Filters=[
                {'Name': 'tag:DR', 'Values': ['true']},
                {'Name': 'instance-state-name', 'Values': ['stopped']}
            ]
        )
        
        for reservation in ec2_instances['Reservations']:
            for instance in reservation['Instances']:
                try:
                    ec2.start_instances(InstanceIds=[instance['InstanceId']])
                    results['actions_taken'].append(f'Started EC2 instance: {instance["InstanceId"]}')
                except Exception as e:
                    results['errors'].append(f'Error starting EC2 instance {instance["InstanceId"]}: {str(e)}')
        
        backup_jobs = backup.list_backup_jobs(
            ByState='COMPLETED',
            MaxResults=10
        )
        
        if backup_jobs['BackupJobs']:
            latest_backup = backup_jobs['BackupJobs'][0]
            results['actions_taken'].append(f'Latest backup available: {latest_backup["BackupJobId"]}')
        
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject='DR Failover Completed',
            Message=f'DR failover process completed. Actions: {len(results["actions_taken"])}, Errors: {len(results["errors"])}'
        )
        
    except Exception as e:
        results['errors'].append(f'Critical error in failover process: {str(e)}')
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject='DR Failover Failed',
            Message=f'DR failover process failed: {str(e)}'
        )
    
    return {
        'statusCode': 200 if not results['errors'] else 500,
        'body': json.dumps(results)
    }

