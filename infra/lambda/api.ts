import { createHash, randomBytes } from 'node:crypto';
import { gunzipSync, gzipSync } from 'node:zlib';
import { BatchWriteCommand, DeleteCommand, GetCommand, PutCommand, QueryCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { HttpError, TABLE, db, requireUser, signAccess, userPk } from './common';

type Event = {
  rawPath: string;
  headers: Record<string, string | undefined>;
  body?: string;
  isBase64Encoded?: boolean;
  requestContext: { http: { method: string } };
};

const GOOGLE_AUDIENCES = (process.env.GOOGLE_CLIENT_IDS ?? '').split(',').filter(Boolean);
const GOOGLE_JWKS = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));
const REFRESH_TTL_SECONDS = 30 * 24 * 3600;
const MAX_PROFILES = 10;
const MAX_VALUE_BYTES = 380 * 1024; // DynamoDB item limit is 400 KB; values are stored gzipped
const KEY_RE = /^[A-Za-z0-9_.-]{1,64}$/;

const json = (status: number, body: unknown) => ({
  statusCode: status,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});

const sha = (s: string) => createHash('sha256').update(s).digest('hex');
const pad = (n: number) => String(n).padStart(10, '0');

function parseBody(e: Event): any {
  if (!e.body) return {};
  const raw = e.isBase64Encoded ? Buffer.from(e.body, 'base64').toString() : e.body;
  if (raw.length > 1_500_000) throw new HttpError(413, 'body too large');
  try {
    return JSON.parse(raw);
  } catch {
    throw new HttpError(400, 'invalid json');
  }
}

const pack = (v: unknown): Buffer => {
  const z = gzipSync(Buffer.from(JSON.stringify(v ?? null)));
  if (z.length > MAX_VALUE_BYTES) throw new HttpError(413, 'value too large');
  return z;
};
const unpack = (b: Uint8Array) => JSON.parse(gunzipSync(Buffer.from(b)).toString());

async function nextCounter(sub: string, sk: string, attr: string): Promise<number> {
  const out = await db.send(
    new UpdateCommand({
      TableName: TABLE,
      Key: { pk: userPk(sub), sk },
      UpdateExpression: 'ADD #c :one',
      ExpressionAttributeNames: { '#c': attr },
      ExpressionAttributeValues: { ':one': 1 },
      ReturnValues: 'UPDATED_NEW',
    }),
  );
  return out.Attributes![attr] as number;
}

async function queryAll(pk: string, prefix?: string, forward = true) {
  const items: any[] = [];
  let start: any;
  do {
    const out = await db.send(
      new QueryCommand({
        TableName: TABLE,
        KeyConditionExpression: prefix ? 'pk = :pk AND begins_with(sk, :p)' : 'pk = :pk',
        ExpressionAttributeValues: prefix ? { ':pk': pk, ':p': prefix } : { ':pk': pk },
        ScanIndexForward: forward,
        ExclusiveStartKey: start,
      }),
    );
    items.push(...(out.Items ?? []));
    start = out.LastEvaluatedKey;
  } while (start);
  return items;
}

async function batchDelete(keys: { pk: string; sk: string }[]) {
  for (let i = 0; i < keys.length; i += 25) {
    await db.send(new BatchWriteCommand({ RequestItems: { [TABLE]: keys.slice(i, i + 25).map((Key) => ({ DeleteRequest: { Key } })) } }));
  }
}

async function batchPut(items: Record<string, unknown>[]) {
  for (let i = 0; i < items.length; i += 25) {
    await db.send(new BatchWriteCommand({ RequestItems: { [TABLE]: items.slice(i, i + 25).map((Item) => ({ PutRequest: { Item } })) } }));
  }
}

async function requireProfile(sub: string, pid: string) {
  const out = await db.send(new GetCommand({ TableName: TABLE, Key: { pk: userPk(sub), sk: `PROFILE#${pad(Number(pid))}` } }));
  if (!out.Item) throw new HttpError(404, 'profile not found');
  return out.Item;
}

async function issueTokens(sub: string) {
  const secretPart = randomBytes(32).toString('base64url');
  await db.send(
    new PutCommand({
      TableName: TABLE,
      Item: { pk: userPk(sub), sk: `RT#${sha(secretPart)}`, ttl: Math.floor(Date.now() / 1000) + REFRESH_TTL_SECONDS },
    }),
  );
  return { accessToken: await signAccess(sub), refreshToken: `${Buffer.from(sub).toString('base64url')}.${secretPart}` };
}

const profileDto = (it: any) => ({ id: Number(it.sk.slice('PROFILE#'.length)), name: it.name });
const foodDto = (it: any) => ({ id: it.id, name: it.name, kcal: it.kcal, protein: it.protein, carb: it.carb, fat: it.fat, fiber: it.fiber });
const foodItem = (sub: string, pid: number, id: number, f: any) => ({
  pk: userPk(sub),
  sk: `FOOD#${pad(pid)}#${pad(id)}`,
  id,
  name: String(f.name ?? '').slice(0, 120),
  kcal: Number(f.kcal) || 0,
  protein: Number(f.protein) || 0,
  carb: Number(f.carb) || 0,
  fat: Number(f.fat) || 0,
  fiber: Number(f.fiber) || 0,
});

export const handler = async (e: Event) => {
  try {
    return await route(e);
  } catch (err) {
    if (err instanceof HttpError) return json(err.status, { error: err.message });
    console.error(err);
    return json(500, { error: 'internal error' });
  }
};

async function route(e: Event) {
  const method = e.requestContext.http.method;
  const path = e.rawPath.replace(/\/+$/, '');
  const seg = path.split('/').filter(Boolean);

  // ---- auth (no bearer) ----
  if (method === 'POST' && path === '/auth/google') {
    const { idToken } = parseBody(e);
    if (typeof idToken !== 'string') throw new HttpError(400, 'idToken required');
    let claims;
    try {
      ({ payload: claims } = await jwtVerify(idToken, GOOGLE_JWKS, {
        issuer: ['https://accounts.google.com', 'accounts.google.com'],
        audience: GOOGLE_AUDIENCES,
      }));
    } catch {
      throw new HttpError(401, 'invalid google token');
    }
    if (!claims.sub || claims.email_verified !== true) throw new HttpError(401, 'unverified google account');
    const sub = claims.sub;
    await db.send(
      new UpdateCommand({
        TableName: TABLE,
        Key: { pk: userPk(sub), sk: 'META' },
        UpdateExpression: 'SET email = :e, #n = :n, lastLogin = :t, created = if_not_exists(created, :t)',
        ExpressionAttributeNames: { '#n': 'name' },
        ExpressionAttributeValues: { ':e': claims.email, ':n': claims.name ?? '', ':t': new Date().toISOString() },
      }),
    );
    return json(200, { ...(await issueTokens(sub)), user: { email: claims.email, name: claims.name ?? '' } });
  }

  if (method === 'POST' && path === '/auth/refresh') {
    const { refreshToken } = parseBody(e);
    const [subB64, part] = String(refreshToken ?? '').split('.');
    if (!subB64 || !part) throw new HttpError(401, 'invalid refresh token');
    const sub = Buffer.from(subB64, 'base64url').toString();
    try {
      // One-time use: deleting with a condition makes a replayed token fail.
      await db.send(
        new DeleteCommand({ TableName: TABLE, Key: { pk: userPk(sub), sk: `RT#${sha(part)}` }, ConditionExpression: 'attribute_exists(pk)' }),
      );
    } catch {
      throw new HttpError(401, 'invalid refresh token');
    }
    return json(200, await issueTokens(sub));
  }

  // ---- everything below needs a valid access token ----
  const sub = await requireUser(e.headers);
  const pk = userPk(sub);

  if (method === 'POST' && path === '/auth/logout') {
    const { refreshToken } = parseBody(e);
    const part = String(refreshToken ?? '').split('.')[1];
    if (part) await db.send(new DeleteCommand({ TableName: TABLE, Key: { pk, sk: `RT#${sha(part)}` } }));
    return json(200, { ok: true });
  }

  if (method === 'GET' && path === '/me') {
    const out = await db.send(new GetCommand({ TableName: TABLE, Key: { pk, sk: 'META' } }));
    return json(200, { email: out.Item?.email ?? '', name: out.Item?.name ?? '' });
  }

  if (method === 'DELETE' && path === '/account') {
    const all = await queryAll(pk);
    await batchDelete(all.map((i) => ({ pk: i.pk, sk: i.sk })));
    return json(200, { ok: true });
  }

  if (method === 'POST' && path === '/import') {
    const { profiles } = parseBody(e);
    if (!Array.isArray(profiles) || profiles.length === 0 || profiles.length > MAX_PROFILES) throw new HttpError(400, 'bad profiles');
    const existing = (await queryAll(pk, 'PROFILE#')).length;
    if (existing + profiles.length > MAX_PROFILES) throw new HttpError(409, 'too many profiles');
    const created: { localId: number; id: number }[] = [];
    for (const p of profiles) {
      const pid = await nextCounter(sub, 'META', 'nextProfile');
      const foods: any[] = Array.isArray(p.foods) ? p.foods : [];
      const items: Record<string, unknown>[] = [
        { pk, sk: `PROFILE#${pad(pid)}`, name: String(p.name ?? 'Profile').slice(0, 60), nextFood: foods.length, created: new Date().toISOString() },
      ];
      for (const [k, v] of Object.entries(p.data ?? {})) {
        if (KEY_RE.test(k)) items.push({ pk, sk: `KV#${pad(pid)}#${k}`, v: pack(v) });
      }
      foods.forEach((f, i) => items.push(foodItem(sub, pid, i + 1, f)));
      await batchPut(items);
      created.push({ localId: p.localId, id: pid });
    }
    return json(200, { profiles: created });
  }

  // ---- profiles ----
  if (path === '/profiles') {
    if (method === 'GET') return json(200, { profiles: (await queryAll(pk, 'PROFILE#')).map(profileDto) });
    if (method === 'POST') {
      const { name } = parseBody(e);
      if ((await queryAll(pk, 'PROFILE#')).length >= MAX_PROFILES) throw new HttpError(409, 'too many profiles');
      const pid = await nextCounter(sub, 'META', 'nextProfile');
      await db.send(
        new PutCommand({ TableName: TABLE, Item: { pk, sk: `PROFILE#${pad(pid)}`, name: String(name ?? 'Profile').slice(0, 60), nextFood: 0, created: new Date().toISOString() } }),
      );
      return json(200, { id: pid });
    }
  }

  if (seg[0] === 'profiles' && seg.length >= 2) {
    const pid = Number(seg[1]);
    if (!Number.isInteger(pid) || pid < 1) throw new HttpError(400, 'bad profile id');

    if (seg.length === 2 && method === 'PATCH') {
      await requireProfile(sub, seg[1]);
      const { name } = parseBody(e);
      await db.send(
        new UpdateCommand({
          TableName: TABLE,
          Key: { pk, sk: `PROFILE#${pad(pid)}` },
          UpdateExpression: 'SET #n = :n',
          ExpressionAttributeNames: { '#n': 'name' },
          ExpressionAttributeValues: { ':n': String(name ?? '').slice(0, 60) },
        }),
      );
      return json(200, { ok: true });
    }

    if (seg.length === 2 && method === 'DELETE') {
      await requireProfile(sub, seg[1]);
      const mine = [...(await queryAll(pk, `KV#${pad(pid)}#`)), ...(await queryAll(pk, `FOOD#${pad(pid)}#`))];
      await batchDelete([...mine.map((i) => ({ pk: i.pk, sk: i.sk })), { pk, sk: `PROFILE#${pad(pid)}` }]);
      return json(200, { ok: true });
    }

    if (seg[2] === 'data') {
      await requireProfile(sub, seg[1]);
      if (seg.length === 3 && method === 'GET') {
        const prefix = `KV#${pad(pid)}#`;
        const data: Record<string, unknown> = {};
        for (const it of await queryAll(pk, prefix)) data[it.sk.slice(prefix.length)] = unpack(it.v);
        return json(200, { data });
      }
      if (seg.length === 4 && method === 'PUT') {
        if (!KEY_RE.test(seg[3])) throw new HttpError(400, 'bad key');
        const { value } = parseBody(e);
        await db.send(new PutCommand({ TableName: TABLE, Item: { pk, sk: `KV#${pad(pid)}#${seg[3]}`, v: pack(value) } }));
        return json(200, { ok: true });
      }
    }

    if (seg[2] === 'foods') {
      await requireProfile(sub, seg[1]);
      if (seg.length === 3 && method === 'GET') {
        return json(200, { foods: (await queryAll(pk, `FOOD#${pad(pid)}#`, false)).map(foodDto) });
      }
      if (seg.length === 3 && method === 'POST') {
        const id = await nextCounter(sub, `PROFILE#${pad(pid)}`, 'nextFood');
        await db.send(new PutCommand({ TableName: TABLE, Item: foodItem(sub, pid, id, parseBody(e)) }));
        return json(200, { id });
      }
      if (seg.length === 4 && method === 'PUT') {
        const id = Number(seg[3]);
        await db.send(new PutCommand({ TableName: TABLE, Item: foodItem(sub, pid, id, parseBody(e)) }));
        return json(200, { ok: true });
      }
      if (seg.length === 4 && method === 'DELETE') {
        await db.send(new DeleteCommand({ TableName: TABLE, Key: { pk, sk: `FOOD#${pad(pid)}#${pad(Number(seg[3]))}` } }));
        return json(200, { ok: true });
      }
    }
  }

  throw new HttpError(404, 'not found');
}
