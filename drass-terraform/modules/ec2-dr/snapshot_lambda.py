import boto3
import json
import os
from datetime import datetime, timezone

ec2 = boto3.client('ec2')
sns = boto3.client('sns')

def handler(event, context):
    instance_ids = os.environ['INSTANCE_IDS'].split(',')
    dr_region = os.environ['DR_REGION']
    kms_key_id = os.environ.get('KMS_KEY_ID', '')
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    
    results = []
    
    for instance_id in instance_ids:
        if not instance_id.strip():
            continue
            
        try:
            volumes = ec2.describe_volumes(
                Filters=[
                    {'Name': 'attachment.instance-id', 'Values': [instance_id.strip()]}
                ]
            )
            
            for volume in volumes['Volumes']:
                snapshot = ec2.create_snapshot(
                    VolumeId=volume['VolumeId'],
                    Description=f"DR snapshot for {instance_id} - {datetime.now(timezone.utc).isoformat()}",
                    TagSpecifications=[
                        {
                            'ResourceType': 'snapshot',
                            'Tags': [
                                {'Key': 'DR', 'Value': 'true'},
                                {'Key': 'InstanceId', 'Value': instance_id},
                                {'Key': 'CreatedBy', 'Value': 'Lambda'}
                            ]
                        }
                    ]
                )
                
                if kms_key_id:
                    ec2.copy_snapshot(
                        SourceRegion=os.environ['AWS_REGION'],
                        SourceSnapshotId=snapshot['SnapshotId'],
                        DestinationRegion=dr_region,
                        KmsKeyId=kms_key_id,
                        Description=f"DR copy for {instance_id}"
                    )
                
                results.append({
                    'instance_id': instance_id,
                    'volume_id': volume['VolumeId'],
                    'snapshot_id': snapshot['SnapshotId'],
                    'status': 'success'
                })
        except Exception as e:
            results.append({
                'instance_id': instance_id,
                'status': 'error',
                'error': str(e)
            })
            
            sns.publish(
                TopicArn=sns_topic_arn,
                Subject=f"EC2 DR Snapshot Failed: {instance_id}",
                Message=f"Error creating snapshot for instance {instance_id}: {str(e)}"
            )
    
    return {
        'statusCode': 200,
        'body': json.dumps(results)
    }

