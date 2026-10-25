import { UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { HttpError, TABLE, db, requireUser, secret, userPk } from './common';

type Event = {
  headers: Record<string, string | undefined>;
  body?: string;
  isBase64Encoded?: boolean;
  requestContext: { http: { method: string } };
};

const DAILY_LIMIT = Number(process.env.DAILY_AI_LIMIT ?? '150');

/**
 * The AI proxy: same contract as the old Cloudflare Worker (`POST /chat`
 * forwards the body to OpenAI), but behind the user's session and a per-user
 * daily quota. Runs behind a Function URL because HTTP API caps at 30 s and
 * the app's AI calls wait up to 40 s.
 */
export const handler = async (e: Event) => {
  try {
    if (e.requestContext.http.method === 'OPTIONS') return { statusCode: 204 };
    const sub = await requireUser(e.headers);
    // Cheap "is my session valid and is the proxy up" check; never reaches OpenAI.
    if (e.requestContext.http.method === 'GET') return { statusCode: 200, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ok: true }) };

    const day = new Date().toISOString().slice(0, 10);
    try {
      await db.send(
        new UpdateCommand({
          TableName: TABLE,
          Key: { pk: userPk(sub), sk: `QUOTA#${day}` },
          UpdateExpression: 'ADD #c :one SET #t = :ttl',
          ConditionExpression: 'attribute_not_exists(#c) OR #c < :max',
          ExpressionAttributeNames: { '#c': 'count', '#t': 'ttl' },
          ExpressionAttributeValues: { ':one': 1, ':max': DAILY_LIMIT, ':ttl': Math.floor(Date.now() / 1000) + 3 * 24 * 3600 },
        }),
      );
    } catch {
      throw new HttpError(429, 'daily AI limit reached');
    }

    const body = e.isBase64Encoded ? Buffer.from(e.body ?? '', 'base64').toString() : (e.body ?? '');
    if (body.length > 200_000) throw new HttpError(413, 'body too large');

    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${await secret(process.env.OPENAI_PARAM!)}`, 'Content-Type': 'application/json' },
      body,
    });
    return { statusCode: res.status, headers: { 'Content-Type': 'application/json' }, body: await res.text() };
  } catch (err) {
    if (err instanceof HttpError) return { statusCode: err.status, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ error: { message: err.message } }) };
    console.error(err);
    return { statusCode: 500, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ error: { message: 'internal error' } }) };
  }
};
