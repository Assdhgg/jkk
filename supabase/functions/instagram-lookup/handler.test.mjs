import test from "node:test";
import assert from "node:assert/strict";
import { createLookupHandler } from "./handler.ts";

const config = {
  supabaseUrl: "https://synthetic.supabase.test",
  supabaseAnonKey: "public-key",
  metaAccessToken: "private-test-token",
  metaInstagramUserId: "12345",
};
const request = (username, authorization = "Bearer user-token") =>
  new Request("https://edge.test/instagram-lookup", {
    method: "POST",
    headers: { authorization, "content-type": "application/json" },
    body: JSON.stringify({ username }),
  });
const response = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
function fakeFetch(options = {}) {
  const calls = [];
  const fn = (url, init = {}) => {
    calls.push({ url: String(url), init });
    if (String(url).endsWith("/auth/v1/user")) {
      return Promise.resolve(response({}, options.authStatus ?? 200));
    }
    if (String(url).endsWith("/rest/v1/rpc/reserve_instagram_lookup")) {
      return Promise.resolve(
        response(options.quota ?? true, options.quotaStatus ?? 200),
      );
    }
    return Promise.resolve(response(
      options.graphBody ??
        { business_discovery: { id: "42", username: "Example" } },
      options.graphStatus ?? 200,
    ));
  };
  return { fn, calls };
}
test("authenticated exact lookup returns only the matching professional username", async () => {
  const { fn, calls } = fakeFetch();
  const result = await createLookupHandler(config, fn)(request("@example"));
  assert.equal(result.status, 200);
  assert.deepEqual(await result.json(), { username: "Example" });
  assert.equal(calls.length, 3);
  const url = new URL(calls[2].url);
  assert.equal(url.origin, "https://graph.facebook.com");
  assert.equal(url.pathname, "/v27.0/12345");
  assert.equal(
    url.searchParams.get("fields"),
    "business_discovery.username(example){id,username}",
  );
  assert.equal(url.searchParams.has("access_token"), false);
  assert.equal(
    calls[2].init.headers.Authorization,
    "Bearer private-test-token",
  );
  assert.equal(calls[1].init.headers.Authorization, "Bearer user-token");
});
test("invalid requests never reach providers", async () => {
  const { fn, calls } = fakeFetch();
  const handler = createLookupHandler(config, fn);
  for (const value of ["not/valid", "a".repeat(31), "@", "x?fields=bad"]) {
    assert.equal((await handler(request(value))).status, 400);
  }
  assert.equal((await handler(request("valid", ""))).status, 401);
  assert.equal(
    (await handler(new Request("https://edge.test/", { method: "GET" })))
      .status,
    405,
  );
  assert.equal(calls.length, 0);
});
test("authentication, active account and quota fail closed", async () => {
  for (
    const [options, status] of [[{ authStatus: 401 }, 401], [{
      quotaStatus: 403,
    }, 403], [{ quota: false }, 429]]
  ) {
    const { fn, calls } = fakeFetch(options);
    assert.equal(
      (await createLookupHandler(config, fn)(request("example"))).status,
      status,
    );
    assert.ok(calls.length < 3);
  }
});
test("missing Meta configuration and provider failures never produce fabricated results", async () => {
  const { fn, calls } = fakeFetch();
  assert.equal(
    (await createLookupHandler({ ...config, metaAccessToken: "" }, fn)(
      request("example"),
    )).status,
    503,
  );
  assert.equal(calls.length, 1);
  for (
    const [options, status, error] of [
      [
        { graphStatus: 400, graphBody: { error: { code: 100 } } },
        404,
        "not_found_or_unsupported",
      ],
      [
        { graphStatus: 400, graphBody: { error: { code: 190 } } },
        503,
        "lookup_unavailable",
      ],
      [
        { graphStatus: 429, graphBody: { error: { code: 4 } } },
        429,
        "rate_limited",
      ],
      [
        {
          graphBody: { business_discovery: { id: "42", username: "another" } },
        },
        503,
        "lookup_unavailable",
      ],
    ]
  ) {
    const mock = fakeFetch(options);
    const result = await createLookupHandler(config, mock.fn)(
      request("example"),
    );
    assert.equal(result.status, status);
    assert.deepEqual(await result.json(), { error });
  }
});
