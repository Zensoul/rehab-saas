import json
import boto3
from datetime import datetime
import os

s3 = boto3.client('s3')
bucket_name = os.environ.get('S3_BUCKET', 'rehab-dev-raw-566807')
env = os.environ.get('ENVIRONMENT', 'dev')

def lambda_handler(event, context):
    # Intake data assumed as the entire event payload
    intake_data = event

    now = datetime.utcnow()
    prefix = f"{env}/intakes/{now.year}/{now.month:02d}/{now.day:02d}/"
    filename = f"intake_{now.strftime('%H%M%S%f')}.json"
    key = prefix + filename

    s3.put_object(
        Bucket=bucket_name,
        Key=key,
        Body=json.dumps(intake_data),
        ServerSideEncryption='aws:kms',
        SSEKMSKeyId='arn:aws:kms:ap-south-1:095289934056:key/6533fb52-7111-4662-9d4b-304553b2225d'
    )

    return {
        "statusCode": 200,
        "body": f"Saved intake to s3://{bucket_name}/{key}",
    }
