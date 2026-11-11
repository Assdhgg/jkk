import { fcmMessage } from './payload.mjs';
import { createHandler } from './handler.mjs';

declare const EdgeRuntime: { waitUntil(task: Promise<unknown>): void };

const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const project = Deno.env.get('FCM_PROJECT_ID') ?? '';
const email = Deno.env.get('FCM_CLIENT_EMAIL') ?? '';
const privateKey = (Deno.env.get('FCM_PRIVATE_KEY') ?? '').replaceAll('\\n', '\n');
const encode = (value: Uint8Array) => btoa(String.fromCharCode(...value)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
const text64 = (value: string) => encode(new TextEncoder().encode(value));
let cachedToken: {value: string; expiresAt: number} | undefined;
async function accessToken() {
  if (cachedToken && cachedToken.expiresAt > Date.now()) return cachedToken.value;
  if (!project || !email || !privateKey) throw new Error('Missing push configuration');
  const now = Math.floor(Date.now() / 1000);
  const header = text64(JSON.stringify({alg: 'RS256', typ: 'JWT'}));
  const payload = text64(JSON.stringify({iss: email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600}));
  const keyData = Uint8Array.from(atob(privateKey.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', keyData, {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'}, false, ['sign']);
  const input = `${header}.${payload}`;
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(input)));
  const body = new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${input}.${encode(signature)}`});
  const response = await fetch('https://oauth2.googleapis.com/token', {method: 'POST', body, signal: AbortSignal.timeout(10000)});
  if (!response.ok) throw new Error('Push token unavailable');
  const value = await response.json();
  if (typeof value.access_token !== 'string') throw new Error('Push token unavailable');
  cachedToken = {value: value.access_token, expiresAt: Date.now() + Math.max(0, Math.min(Number(value.expires_in) || 3600, 3600) - 60) * 1000};
  return cachedToken.value;
}
async function rpc(name: string, body: Record<string, unknown>) {
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`, {method: 'POST', headers: {apikey: serviceKey, authorization: `Bearer ${serviceKey}`, 'content-type': 'application/json'}, body: JSON.stringify(body), signal: AbortSignal.timeout(10000)});
  if (!response.ok) throw new Error('Push queue unavailable');
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}
const handler = createHandler({
  secret: serviceKey,
  workerSecret: Deno.env.get('PUSH_WORKER_SECRET') ?? '',
  claim: async () => { await accessToken(); return await rpc('claim_push_jobs_v2', {p_limit: 100}); },
  send: async (deviceToken: string, title: string, body: string, kind: string) => {
    const token = await accessToken();
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(project)}/messages:send`, {method: 'POST', headers: {authorization: `Bearer ${token}`, 'content-type': 'application/json'}, body: JSON.stringify(fcmMessage(deviceToken, title, body, kind)), signal: AbortSignal.timeout(10000)});
    if (response.ok) return {success: true, permanent: false};
    let permanent = false;
    try { const data = await response.json(); permanent = Array.isArray(data.error?.details) && data.error.details.some((d: {errorCode?: string}) => d.errorCode === 'UNREGISTERED'); } catch (_) { /* Retry unknown responses. */ }
    return {success: false, permanent};
  },
  continueDelivery: () => EdgeRuntime.waitUntil(fetch(`${supabaseUrl}/functions/v1/push-delivery`, {
    method: 'POST', headers: {authorization: `Bearer ${serviceKey}`, 'content-type': 'application/json',
      'x-push-worker-secret': Deno.env.get('PUSH_WORKER_SECRET') ?? ''},
    body: '{}', signal: AbortSignal.timeout(10000),
  }).then(response => response.body?.cancel()).catch(() => {})),
  finish: async (id: string, lease: string, success: boolean, permanent: boolean) => { await rpc('finish_push_job', {p_id: id, p_lease: lease, p_success: success, p_permanent: permanent}); },
});
Deno.serve(handler);
