import { S3Client, PutObjectCommand, HeadObjectCommand, CopyObjectCommand, DeleteObjectCommand } from 'npm:@aws-sdk/client-s3@3.899.0';
import { getSignedUrl } from 'npm:@aws-sdk/s3-request-presigner@3.899.0';
import { createHandler } from './handler.mjs';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const account = Deno.env.get('R2_ACCOUNT_ID') ?? '';
const bucket = Deno.env.get('R2_BUCKET') ?? '';
const accessKeyId = Deno.env.get('R2_ACCESS_KEY_ID') ?? '';
const secretAccessKey = Deno.env.get('R2_SECRET_ACCESS_KEY') ?? '';
const publicBase = Deno.env.get('R2_PUBLIC_BASE_URL') ?? '';
const contentType = 'application/vnd.android.package-archive';
const s3 = new S3Client({ region: 'auto', endpoint: `https://${account}.r2.cloudflarestorage.com`, credentials: { accessKeyId, secretAccessKey }, requestChecksumCalculation: 'WHEN_REQUIRED' });

async function authorize(authorization: string): Promise<string | null> {
  if (!supabaseUrl || !anonKey || !serviceKey || !/^[a-f0-9]{32}$/.test(account) || !bucket || !accessKeyId || !secretAccessKey || !publicBase) throw new Error('Missing configuration');
  const headers = { apikey: anonKey, authorization };
  const user = await fetch(`${supabaseUrl}/auth/v1/user`, {headers, signal: AbortSignal.timeout(8000)});
  if (!user.ok) return null;
  const identity = await user.json();
  const editor = await fetch(`${supabaseUrl}/rest/v1/rpc/app_release_editor`, { method: 'POST', headers: {...headers, 'content-type': 'application/json'}, body: '{}', signal: AbortSignal.timeout(8000) });
  if (!editor.ok || await editor.json() !== true) return null;
  return identity.id;
}

Deno.serve(createHandler({
  publicBase,
  authorize,
  signUpload: (key: string, size: number) => getSignedUrl(s3, new PutObjectCommand({Bucket: bucket, Key: key, ContentLength: size, ContentType: contentType, IfNoneMatch: '*'}), {expiresIn: 900, signableHeaders: new Set(['content-length', 'content-type', 'if-none-match'])}),
  copyUpload: async (source: string, target: string, size: number) => {
    const head = await s3.send(new HeadObjectCommand({Bucket: bucket, Key: source}));
    if (head.ContentLength !== size || !head.ETag) throw new Error('Invalid upload');
    await s3.send(new CopyObjectCommand({Bucket: bucket, Key: target, CopySource: `${bucket}/${source}`, CopySourceIfMatch: head.ETag}));
  },
  publish: async ({userId, name, downloadUrl, data}: {userId: string; name: string; downloadUrl: string; data: Record<string, unknown>}) => {
    // Recheck the editor's current session after the potentially slow upload/copy.
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/publish_r2_app_release`, {
      method: 'POST', headers: {apikey: serviceKey, authorization: `Bearer ${serviceKey}`, 'content-type': 'application/json'},
      body: JSON.stringify({p_user_id: userId, p_version_code: data.versionCode, p_version_name: data.versionName, p_path: name, p_sha256: data.sha256, p_size: data.size, p_notes: data.notes, p_url: downloadUrl}), signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error('Publication failed');
    // Safe to leave failed cleanups as staging orphans; configure bucket lifecycle.
    await s3.send(new DeleteObjectCommand({Bucket: bucket, Key: data.key as string})).catch(() => {});
  },
}));
