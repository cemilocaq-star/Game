import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-oxenwar-server-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length || a.length === 0) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });

  const serverSecret = Deno.env.get("OXENWAR_SERVER_SECRET") ?? "";
  const suppliedSecret = request.headers.get("x-oxenwar-server-secret") ?? "";
  if (!constantTimeEqual(serverSecret, suppliedSecret)) {
    return json(403, { error: "server_authentication_failed" });
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);
  if (!tokenMatch) return json(401, { error: "missing_user_token" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(503, { error: "server_configuration_incomplete" });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(tokenMatch[1]);
  if (userError || !userData.user) return json(401, { error: "invalid_user_token" });

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }

  const score = body.score;
  const xp = body.xp;
  const collections = body.collections;
  if (!Number.isInteger(score) || (score as number) < 0 || (score as number) > 20000 ||
      !Number.isInteger(xp) || (xp as number) < 0 || (xp as number) > 50000 ||
      !Array.isArray(collections) || collections.length > 512 ||
      !collections.every((id) => typeof id === "string" && /^(orb_(0[0-9]|1[01])|secret_404)$/.test(id))) {
    return json(400, { error: "invalid_match_result" });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await admin.rpc("oxenwar_apply_server_result", {
    p_user_id: userData.user.id,
    p_score: score,
    p_xp: xp,
    p_collection_ids: collections,
  });
  if (error) return json(500, { error: "result_persistence_failed" });
  return json(200, { ok: true });
});
