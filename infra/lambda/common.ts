import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { SignJWT, jwtVerify } from 'jose';

export const TABLE = process.env.TABLE!;
export const db = DynamoDBDocumentClient.from(new DynamoDBClient({}), { marshallOptions: { removeUndefinedValues: true } });

const ssm = new SSMClient({});
const secretCache = new Map<string, { value: string; at: number }>();
const SECRET_TTL_MS = 5 * 60 * 1000;

/** SecureString parameters are cached per warm container for 5 minutes, so a rotated key is picked up without a redeploy. */
export async function secret(name: string): Promise<string> {
  const hit = secretCache.get(name);
  if (hit && Date.now() - hit.at < SECRET_TTL_MS) return hit.value;
  const out = await ssm.send(new GetParameterCommand({ Name: name, WithDecryption: true }));
  const value = out.Parameter!.Value!;
  secretCache.set(name, { value, at: Date.now() });
  return value;
}

export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

const ACCESS_TTL_SECONDS = 60 * 60;

export async function signAccess(sub: string): Promise<string> {
  const key = new TextEncoder().encode(await secret(process.env.JWT_PARAM!));
  return new SignJWT({}).setProtectedHeader({ alg: 'HS256' }).setSubject(sub).setIssuedAt().setExpirationTime(`${ACCESS_TTL_SECONDS}s`).sign(key);
}

/** Returns the Google `sub` of the caller; everything is scoped to it. */
export async function requireUser(headers: Record<string, string | undefined>): Promise<string> {
  const h = headers['authorization'] ?? headers['Authorization'] ?? '';
  const m = /^Bearer (.+)$/.exec(h);
  if (!m) throw new HttpError(401, 'unauthorized');
  try {
    const key = new TextEncoder().encode(await secret(process.env.JWT_PARAM!));
    const { payload } = await jwtVerify(m[1], key, { algorithms: ['HS256'] });
    if (!payload.sub) throw new Error('no sub');
    return payload.sub;
  } catch {
    throw new HttpError(401, 'unauthorized');
  }
}

export const userPk = (sub: string) => `USER#${sub}`;
