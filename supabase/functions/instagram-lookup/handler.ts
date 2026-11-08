export type LookupConfig = {
  supabaseUrl: string;
  supabaseAnonKey: string;
  metaAccessToken: string;
  metaInstagramUserId: string;
};

type Fetcher = typeof fetch;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};
const json = (status: number, body: Record<string, unknown>): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
const validUsername = /^[A-Za-z0-9._]{1,30}$/;

export function createLookupHandler(
  config: LookupConfig,
  fetcher: Fetcher = fetch,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    if (request.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    const authorization = request.headers.get("authorization") ?? "";
    if (!/^Bearer\s+\S+$/i.test(authorization)) {
      return json(401, { error: "unauthorized" });
    }
    if (!config.supabaseUrl || !config.supabaseAnonKey) {
      return json(503, { error: "lookup_unavailable" });
    }

    let username: unknown;
    try {
      const raw = await request.text();
      if (raw.length > 2048) return json(400, { error: "invalid_username" });
      const body = JSON.parse(raw);
      username = body && typeof body === "object" ? body.username : undefined;
    } catch {
      return json(400, { error: "invalid_username" });
    }
    if (typeof username !== "string" || username.length > 32) {
      return json(400, { error: "invalid_username" });
    }
    const handle = username.trim().replace(/^@/, "");
    if (!validUsername.test(handle)) {
      return json(400, { error: "invalid_username" });
    }

    const headers = {
      "apikey": config.supabaseAnonKey,
      "Authorization": authorization,
    };
    try {
      const user = await fetcher(`${config.supabaseUrl}/auth/v1/user`, {
        headers,
        signal: AbortSignal.timeout(8000),
      });
      if (!user.ok) return json(401, { error: "unauthorized" });
      if (
        !config.metaAccessToken ||
        !/^\d{1,32}$/.test(config.metaInstagramUserId)
      ) {
        return json(503, { error: "lookup_unavailable" });
      }
      const quota = await fetcher(
        `${config.supabaseUrl}/rest/v1/rpc/reserve_instagram_lookup`,
        {
          method: "POST",
          headers: { ...headers, "Content-Type": "application/json" },
          body: "{}",
          signal: AbortSignal.timeout(8000),
        },
      );
      if (!quota.ok) return json(403, { error: "access_denied" });
      if (await quota.json() !== true) {
        return json(429, { error: "rate_limited" });
      }
      const graph = new URL(
        `https://graph.facebook.com/v27.0/${config.metaInstagramUserId}`,
      );
      graph.searchParams.set(
        "fields",
        `business_discovery.username(${handle}){id,username}`,
      );
      const result = await fetcher(graph, {
        headers: { "Authorization": `Bearer ${config.metaAccessToken}` },
        redirect: "error",
        signal: AbortSignal.timeout(8000),
      });
      const body = await result.json();
      if (!result.ok) {
        const code = body?.error?.code;
        if (result.status === 429 || [4, 17, 32, 613].includes(code)) {
          return json(429, { error: "rate_limited" });
        }
        if (code === 100) {
          return json(404, { error: "not_found_or_unsupported" });
        }
        return json(503, { error: "lookup_unavailable" });
      }
      const account = body?.business_discovery;
      if (
        !account || typeof account.username !== "string" ||
        !validUsername.test(account.username) ||
        account.username.toLowerCase() !== handle.toLowerCase() ||
        typeof account.id !== "string" || !/^\d+$/.test(account.id)
      ) {
        return json(503, { error: "lookup_unavailable" });
      }
      return json(200, { username: account.username });
    } catch {
      return json(503, { error: "lookup_unavailable" });
    }
  };
}
