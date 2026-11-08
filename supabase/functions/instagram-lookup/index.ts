import { createLookupHandler } from "./handler.ts";

Deno.serve(createLookupHandler({
  supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
  supabaseAnonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  metaAccessToken: Deno.env.get("META_INSTAGRAM_ACCESS_TOKEN") ?? "",
  metaInstagramUserId: Deno.env.get("META_INSTAGRAM_USER_ID") ?? "",
}));
