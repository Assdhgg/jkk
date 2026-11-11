const messages = {
  app_update: ['App update available', 'Open Freelan Space to download and install the latest version.'],
  approved: ['Submission approved', 'Open Freelan Space to see your update.'],
  rejected: ['Submission reviewed', 'Open Freelan Space to see your update.'],
  coins_received: ['Coins received', 'Open Freelan Space to see your update.'],
  support_reply: ['Support replied', 'Open Freelan Space to see your update.'],
};
function equalSecret(a, b) {
  const x = new TextEncoder().encode(a), y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}
export function createHandler({secret, workerSecret, claim, send, finish}) {
  return async request => {
    if (request.method !== 'POST') return new Response('Method not allowed', {status: 405});
    const auth = request.headers.get('authorization') ?? '';
    const workerAuth = request.headers.get('x-push-worker-secret') ?? '';
    const validServiceKey = secret && equalSecret(auth, `Bearer ${secret}`);
    const validWorkerKey = workerSecret && equalSecret(workerAuth, workerSecret);
    if (!validServiceKey && !validWorkerKey) return new Response('Unauthorized', {status: 401});
    try {
      const jobs = await claim();
      const results = await Promise.all(jobs.map(async job => {
        let outcome = {success: false, permanent: false};
        try {
          const [title, body] = job.kind === 'admin_message' && typeof job.title === 'string' && typeof job.body === 'string'
            ? [job.title, job.body]
            : messages[job.kind] ?? ['Freelan Space', 'Open Freelan Space to see your update.'];
          outcome = await send(job.token, title, body, job.kind);
        } catch (_) { /* Leased jobs are retried on transient errors. */ }
        try { await finish(job.job_id, job.lease_id, outcome.success, outcome.permanent); return outcome.success ? 'sent' : 'retry'; }
        catch (_) { return 'unconfirmed'; }
      }));
      return Response.json({processed: results.length, sent: results.filter(x => x === 'sent').length, unconfirmed: results.filter(x => x === 'unconfirmed').length});
    } catch (_) { return new Response('Push worker unavailable', {status: 503}); }
  };
}
