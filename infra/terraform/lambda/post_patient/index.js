// index.js
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

const ddb = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3({ apiVersion: '2006-03-01' });

/**
 * Write raw intake JSON to S3 with SSE-KMS. Minimal logging (no PHI).
 */
async function writeRawIntakeToS3(item) {
  const dt = new Date(item.created_at || new Date().toISOString());
  const YYYY = dt.getUTCFullYear();
  const MM = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const DD = String(dt.getUTCDate()).padStart(2, '0');

  const env = process.env.ENVIRONMENT || 'dev';
  const key = `${env}/intakes/${YYYY}/${MM}/${DD}/${item.intake_id || uuidv4()}.json`;
  const body = JSON.stringify(item);

  const params = {
    Bucket: process.env.RAW_BUCKET,
    Key: key,
    Body: body,
    ServerSideEncryption: 'aws:kms'
  };
  // Add SSEKMSKeyId only if provided (CMK)
  if (process.env.KMS_KEY_ARN) params.SSEKMSKeyId = process.env.KMS_KEY_ARN;

  // Minimal logging only
  await s3.putObject(params).promise();
  console.log(`WROTE_RAW_S3 key=${key} bytes=${body.length}`);
  return key;
}

/**
 * Lambda handler: creates item in DynamoDB, writes raw copy to S3.
 * Assumes event.body contains JSON intake.
 */
exports.handler = async (event) => {
  try {
    const now = new Date().toISOString();
    let payload = {};

    // if coming from API Gateway
    if (event.body) {
      payload = (typeof event.body === 'string') ? JSON.parse(event.body) : event.body;
    } else {
      payload = event; // for direct invoke/testing
    }

    // Build DynamoDB item (ensure intake_id + created_at present)
    const item = {
      intake_id: payload.intake_id || `intake-${Date.now()}`,
      tenant_id: payload.tenant_id || 'unknown',
      status: payload.status || 'new',
      created_at: payload.created_at || now,
      payload: payload.payload || payload // keep original payload nested
    };

    // Write to DynamoDB
    const tableName = process.env.INTAKES_TABLE;
    if (!tableName) throw new Error("Missing INTAKES_TABLE env var");

    await ddb.put({
      TableName: tableName,
      Item: item
    }).promise();

    // Best-effort write raw to S3 (awaiting to ensure durability)
    try {
      const s3key = await writeRawIntakeToS3(item);
      // include S3 key in response metadata (non-PHI)
      return {
        statusCode: 200,
        body: JSON.stringify({ success: true, item: item, raw_s3_key: s3key })
      };
    } catch (s3Err) {
      // If S3 fails, still return success for API but signal warning
      console.error("RAW_S3_ERROR", s3Err.message || s3Err);
      return {
        statusCode: 200,
        body: JSON.stringify({ success: true, item: item, raw_s3_warning: "failed to write raw S3 copy" })
      };
    }
  } catch (err) {
    console.error("HANDLER_ERROR", err);
    return {
      statusCode: 500,
      body: JSON.stringify({ success: false, error: err.message })
    };
  }
};
