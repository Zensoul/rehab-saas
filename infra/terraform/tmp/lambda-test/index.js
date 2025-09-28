// /tmp/lambda-test/index.js
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const ddb = new AWS.DynamoDB.DocumentClient();

const TABLE = process.env.INTAKES_TABLE;
const BUCKET = process.env.RAW_BUCKET;
const ENV = process.env.ENVIRONMENT || 'dev';

function yyyymmdd() {
  const d = new Date();
  return `${d.getUTCFullYear()}/${String(d.getUTCMonth()+1).padStart(2,'0')}/${String(d.getUTCDate()).padStart(2,'0')}`;
}

exports.handler = async (event) => {
  // Always log the raw event
  console.log("HANDLER START - raw event:", JSON.stringify(event));

  // parse event for API proxy or direct invocation
  let body = event;
  if (event && typeof event.body === 'string') {
    try { body = JSON.parse(event.body); }
    catch (e) { console.warn("failed to parse event.body as JSON", e); }
  }

  const intakeId = body.intake_id || `intake-${Date.now()}`;
  const item = {
    intake_id: intakeId,
    tenant_id: body.tenant_id || 'unknown',
    status: body.status || 'new',
    created_at: new Date().toISOString(),
    payload: body.payload || {}
  };

  console.log("Prepared item:", JSON.stringify(item));

  // Put to DynamoDB (log success/failure)
  try {
    const res = await ddb.put({ TableName: TABLE, Item: item }).promise();
    console.log("DDB put success:", JSON.stringify(res || {}));
  } catch (err) {
    console.error("DDB put ERROR:", err && err.message ? err.message : err);
  }

  // Compose S3 key and attempt upload (log everything)
  const key = `${ENV}/intakes/${yyyymmdd()}/${item.intake_id}.json`;
  console.log("Attempting S3 putObject", { Bucket: BUCKET, Key: key });

  try {
    const s3res = await s3.putObject({
      Bucket: BUCKET,
      Key: key,
      Body: JSON.stringify(item),
      ContentType: 'application/json'
    }).promise();
    console.log("S3 putObject SUCCESS", JSON.stringify(s3res || {}));
    return {
      statusCode: 200,
      body: JSON.stringify({ success: true, key })
    };
  } catch (err) {
    console.error("S3 putObject FAILED", err && err.message ? err.message : err, { key });
    return {
      statusCode: 500,
      body: JSON.stringify({ success: false, error: String(err), key })
    };
  }
};
