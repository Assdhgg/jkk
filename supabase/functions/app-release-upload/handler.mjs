const MAX_SIZE = 209715200;
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Cache-Control': 'no-store' };
const json = (status, value) => new Response(JSON.stringify(value), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

async function smallBody(req) {
  const reader = req.body?.getReader();
  if (!reader) throw new Error('missing body');
  let total = 0;
  const chunks = [];
  const timer = setTimeout(() => void reader.cancel().catch(() => {}), 8000);
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      total += value.length;
      if (total > 32768) throw new Error('body too large');
      chunks.push(value);
    }
    const data = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) { data.set(chunk, offset); offset += chunk.length; }
    return JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(data));
  } finally { clearTimeout(timer); void reader.cancel().catch(() => {}); reader.releaseLock(); }
}

// All privileged operations are injected so authorization and failure paths can be tested.
export function createHandler({authorize, signUpload, copyUpload, publish, publicBase, randomUUID = () => crypto.randomUUID()}) {
  return async request => {
    if (request.method === 'OPTIONS') return new Response(null, {status: 204, headers: cors});
    if (request.method !== 'POST') return json(405, {error: 'method_not_allowed'});
    const authorization = request.headers.get('authorization') ?? '';
    if (!/^Bearer\s+\S+$/i.test(authorization)) return json(401, {error: 'unauthorized'});
    let data;
    try { data = await smallBody(request); } catch { return json(400, {error: 'invalid_request'}); }
    if (!data || typeof data !== 'object' || !['prepare', 'publish'].includes(data.action) || !Number.isSafeInteger(data.size) || data.size < 4 || data.size > MAX_SIZE) return json(400, {error: 'invalid_request'});
    try {
      const userId = await authorize(authorization);
      if (!userId || !uuid.test(userId)) return json(403, {error: 'access_denied'});
      if (data.action === 'prepare') {
        const key = `staging/${userId}/${randomUUID()}.apk`;
        const url = await signUpload(key, data.size);
        return json(200, {key, url});
      }
      const prefix = `staging/${userId}/`;
      const file = typeof data.key === 'string' && data.key.startsWith(prefix) ? data.key.slice(prefix.length) : '';
      if (!file.endsWith('.apk') || !uuid.test(file.slice(0, -4)) || !Number.isSafeInteger(data.versionCode) || data.versionCode < 1 || data.versionCode > 2100000000 || typeof data.versionName !== 'string' || data.versionName.trim().length < 1 || data.versionName.length > 60 || typeof data.notes !== 'string' || data.notes.length > 4000 || typeof data.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(data.sha256)) return json(400, {error: 'invalid_request'});
      const base = new URL(publicBase);
      if (base.protocol !== 'https:' || base.username || base.password || base.search || base.hash) throw new Error('invalid public base');
      // Keep the opaque release identifier for existing clients while the
      // public object name carries the version and build number.
      const name = `${randomUUID()}.apk`;
      const slug = data.versionName.trim().replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60);
      const version = /[A-Za-z0-9]/.test(slug) ? slug : 'version';
      const target = `releases/freelan-space-v${version}-${data.versionCode}.apk`;
      await copyUpload(data.key, target, data.size, {sha256: data.sha256, versionCode: data.versionCode, versionName: data.versionName.trim()});
      if (await authorize(authorization) !== userId) return json(403, {error: 'access_denied'});
      const downloadUrl = `${base.href.replace(/\/$/, '')}/${target}`;
      await publish({userId, name, downloadUrl, data: {...data, versionName: data.versionName.trim()}});
      return json(200, {published: true});
    } catch {
      // Publication may have committed even if the response was lost.
      return json(503, {error: 'publication_unconfirmed'});
    }
  };
}
