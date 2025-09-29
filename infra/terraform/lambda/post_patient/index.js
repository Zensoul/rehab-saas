const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

const ddb = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3({ apiVersion: '2006-03-01' });

/* ----- Config validation ----- */
const requiredEnv = ['INTAKES_TABLE', 'RAW_BUCKET'];
for (const e of requiredEnv) {
  if (!process.env[e]) {
    console.error(`Missing required env var ${e}`);
    throw new Error(`Missing env var ${e}`);
  }
}
const REDACT_RAW = (process.env.REDACT_RAW || 'false').toLowerCase() === 'true';

/* ----- Simple redaction (shallow, extend for prod) ----- */
function redactPayload(original) {
  if (!original || typeof original !== 'object') return original;
  const phiFields = new Set(['email', 'phone', 'phonenumber', 'name', 'dob', 'ssn']);
  function walk(obj) {
    if (!obj || typeof obj !== 'object') return obj;
    for (const k of Object.keys(obj)) {
      try {
        if (phiFields.has(k.toLowerCase())) obj[k] = '[REDACTED]';
        else if (typeof obj[k] === 'object') walk(obj[k]);
      } catch (ex) {
        // ignore redaction failure for unexpected types
      }
    }
    return obj;
  }
  return walk(JSON.parse(JSON.stringify(original)));
}

/* ----- Write raw intake to S3 (safest payload) ----- */
async function writeRawIntakeToS3(item) {
  const dt = new Date(item.created_at || new Date().toISOString());
  const YYYY = dt.getUTCFullYear();
  const MM = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const DD = String(dt.getUTCDate()).padStart(2, '0');

  const env = process.env.ENVIRONMENT || 'dev';
  const key = `${env}/intakes/${YYYY}/${MM}/${DD}/${item.intake_id || uuidv4()}.json`;

  const safePayload = REDACT_RAW ? redactPayload(item.payload) : item.payload;
  const bodyObj = {
    meta: {
      intake_id: item.intake_id,
      tenant_id: item.tenant_id,
      created_at: item.created_at
    },
    payload: safePayload
  };
  const body = JSON.stringify(bodyObj);

  const params = {
    Bucket: process.env.RAW_BUCKET,
    Key: key,
    Body: body,
    ServerSideEncryption: 'aws:kms'
  };
  if (process.env.KMS_KEY_ARN) params.SSEKMSKeyId = process.env.KMS_KEY_ARN;

  await s3.putObject(params).promise();
  console.log(`WROTE_RAW_S3 key=${key} bytes=${body.length}`);
  return key;
}

/* ----- Lambda handler ----- */
exports.handler = async (event) => {
  try {
    const now = new Date().toISOString();
    let payload = {};

    if (event.body) {
      try {
        payload = (typeof event.body === 'string') ? JSON.parse(event.body) : event.body;
      } catch (parseErr) {
        console.error('BAD_JSON', parseErr);
        return { statusCode: 400, body: JSON.stringify({ success: false, error: 'Invalid JSON body' }) };
      }
    } else {
      payload = event;
    }

    // Extract tenant_id from Cognito JWT claims (adjust claim key as configured)
    const jwtClaims = event.requestContext?.authorizer?.jwt?.claims || {};
    const tokenTenantId = jwtClaims['custom:tenant_id'] || jwtClaims['tenant_id'];

    if (!tokenTenantId) {
      return { statusCode: 401, body: JSON.stringify({ success: false, error: 'Missing tenant authentication' }) };
    }
    if (payload.tenant_id !== tokenTenantId) {
      return { statusCode: 403, body: JSON.stringify({ success: false, error: 'Tenant ID mismatch' }) };
    }

    const item = {
      intake_id: payload.intake_id || uuidv4(),
      tenant_id: payload.tenant_id,
      status: payload.status || 'new',
      created_at: payload.created_at || now,
      payload: payload.payload || payload
    };

    const tableName = process.env.INTAKES_TABLE;
    await ddb.put({ TableName: tableName, Item: item }).promise();

    try {
      const s3key = await writeRawIntakeToS3(item);
      return {
        statusCode: 201,
        body: JSON.stringify({ success: true, item, raw_s3_key: s3key })
      };
    } catch (s3Err) {
      console.error('RAW_S3_ERROR', s3Err);
      return {
        statusCode: 202,
        body: JSON.stringify({ success: true, item, raw_s3_warning: 'failed to write raw S3 copy' })
      };
    }
  } catch (err) {
    console.error('HANDLER_ERROR', err);
    return {
      statusCode: 500,
      body: JSON.stringify({ success: false, error: err.message || 'internal error' })
    };
  }
};
