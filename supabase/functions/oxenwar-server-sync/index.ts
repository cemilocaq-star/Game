import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-oxenwar-server-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const encoder = new TextEncoder();

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

function encodeBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function decodeBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function importHmacKey(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

async function signToken(payload: Record<string, unknown>, secret: string): Promise<string> {
  const encoded = encodeBase64Url(encoder.encode(JSON.stringify(payload)));
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", await importHmacKey(secret), encoder.encode(encoded)));
  return encoded + "." + encodeBase64Url(signature);
}

async function verifyToken(token: string, secret: string): Promise<Record<string, unknown> | null> {
  const parts = token.split(".");
  if (parts.length !== 2 || parts[0].length > 8192 || parts[1].length > 256) return null;
  try {
    const valid = await crypto.subtle.verify(
      "HMAC",
      await importHmacKey(secret),
      decodeBase64Url(parts[1]),
      encoder.encode(parts[0]),
    );
    if (!valid) return null;
    const payload = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[0])));
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) return null;
    return payload as Record<string, unknown>;
  } catch {
    return null;
  }
}

function bearerToken(request: Request): string {
  return (request.headers.get("Authorization") ?? "").match(/^Bearer\s+(.+)$/i)?.[1] ?? "";
}

async function loadSession(admin: ReturnType<typeof createClient>, token: string, secret: string) {
  const claims = await verifyToken(token, secret);
  if (!claims || typeof claims.sub !== "string" || typeof claims.sid !== "string" ||
      typeof claims.exp !== "number" || claims.exp <= Math.floor(Date.now() / 1000)) return null;
  const { data, error } = await admin
    .from("oxenwar_server_sessions")
    .select("session_id,user_id,expires_at,revoked_at")
    .eq("session_id", claims.sid)
    .eq("user_id", claims.sub)
    .gt("expires_at", new Date().toISOString())
    .is("revoked_at", null)
    .maybeSingle();
  if (error || !data) return null;
  return { userId: claims.sub, sessionId: claims.sid };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });

  const serverSecret = Deno.env.get("OXENWAR_SERVER_SECRET") ?? "";
  if (!serverSecret) return json(503, { error: "server_secret_not_configured" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) return json(503, { error: "server_configuration_incomplete" });

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const action = String(body.action ?? "");

  if (action === "issue_ticket") {
    const token = bearerToken(request);
    if (!token) return json(401, { error: "missing_user_token" });
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) return json(401, { error: "invalid_user_token" });

    const userId = authData.user.id;
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("id,username,display_name,avatar_color_id,outfit_id,accessory_id")
      .eq("id", userId)
      .maybeSingle();
    if (profileError || !profile) return json(403, { error: "player_profile_missing" });

    const { data: stats } = await admin
      .from("player_stats")
      .select("total_xp,best_score,total_score,matches_played")
      .eq("user_id", userId)
      .maybeSingle();

    const jti = crypto.randomUUID();
    const expires = Math.floor(Date.now() / 1000) + 60;
    const { error: ticketError } = await admin.from("oxenwar_game_tickets").insert({
      jti,
      user_id: userId,
      expires_at: new Date(expires * 1000).toISOString(),
    });
    if (ticketError) return json(500, { error: "ticket_creation_failed" });

    const ticket = await signToken({
      sub: userId,
      jti,
      exp: expires,
      profile,
      stats: stats ?? {},
    }, serverSecret);
    return json(200, { ticket, expires_at: expires });
  }

  if (action === "redeem_ticket") {
    if (!constantTimeEqual(serverSecret, request.headers.get("x-oxenwar-server-secret") ?? "")) {
      return json(403, { error: "server_authentication_failed" });
    }
    const claims = await verifyToken(String(body.ticket ?? ""), serverSecret);
    if (!claims || typeof claims.sub !== "string" || typeof claims.jti !== "string" ||
        typeof claims.exp !== "number" || claims.exp <= Math.floor(Date.now() / 1000) ||
        !claims.profile || typeof claims.profile !== "object") {
      return json(401, { error: "invalid_or_expired_game_ticket" });
    }

    const { data: redeemed, error: redeemError } = await admin
      .from("oxenwar_game_tickets")
      .update({ redeemed_at: new Date().toISOString() })
      .eq("jti", claims.jti)
      .eq("user_id", claims.sub)
      .is("redeemed_at", null)
      .gt("expires_at", new Date().toISOString())
      .select("jti")
      .maybeSingle();
    if (redeemError || !redeemed) return json(409, { error: "ticket_already_used_or_expired" });

    const sessionId = crypto.randomUUID();
    const sessionExpires = Math.floor(Date.now() / 1000) + 12 * 60 * 60;
    const { error: sessionError } = await admin.from("oxenwar_server_sessions").insert({
      session_id: sessionId,
      user_id: claims.sub,
      expires_at: new Date(sessionExpires * 1000).toISOString(),
    });
    if (sessionError) return json(500, { error: "server_session_creation_failed" });

    const sessionToken = await signToken({
      sub: claims.sub,
      sid: sessionId,
      exp: sessionExpires,
    }, serverSecret);
    return json(200, {
      ok: true,
      user_id: claims.sub,
      profile: claims.profile,
      stats: claims.stats ?? {},
      session_token: sessionToken,
    });
  }

  if (!constantTimeEqual(serverSecret, request.headers.get("x-oxenwar-server-secret") ?? "")) {
    return json(403, { error: "server_authentication_failed" });
  }

  const session = await loadSession(admin, String(body.session_token ?? ""), serverSecret);
  if (!session) return json(401, { error: "invalid_server_session" });

  if (action === "check_friend") {
    const otherId = String(body.friend_user_id ?? "");
    if (!/^[0-9a-f-]{36}$/i.test(otherId) || otherId === session.userId) return json(400, { error: "invalid_friend_id" });
    const low = session.userId < otherId ? session.userId : otherId;
    const high = session.userId < otherId ? otherId : session.userId;
    const { data, error } = await admin.from("friendships")
      .select("user_a")
      .eq("user_a", low)
      .eq("user_b", high)
      .maybeSingle();
    if (error) return json(500, { error: "friendship_lookup_failed" });
    return json(200, { is_friend: !!data });
  }

  if (action === "sync_result") {
    const { score, xp, collections, kills, deaths, damage_dealt, shots_fired, shots_hit, playtime_seconds, outcome } = body;
    if (typeof score !== "number" || !Number.isInteger(score) || score < 0 || score > 20000 ||
        typeof xp !== "number" || !Number.isInteger(xp) || xp < 0 || xp > 50000 ||
        typeof kills !== "number" || !Number.isInteger(kills) || kills < 0 || kills > 5000 ||
        typeof deaths !== "number" || !Number.isInteger(deaths) || deaths < 0 || deaths > 5000 ||
        typeof damage_dealt !== "number" || !Number.isFinite(damage_dealt) || damage_dealt < 0 || damage_dealt > 10000000 ||
        typeof shots_fired !== "number" || !Number.isInteger(shots_fired) || shots_fired < 0 || shots_fired > 20000 ||
        typeof shots_hit !== "number" || !Number.isInteger(shots_hit) || shots_hit < 0 || shots_hit > shots_fired ||
        typeof playtime_seconds !== "number" || !Number.isInteger(playtime_seconds) || playtime_seconds < 0 || playtime_seconds > 7200 ||
        !["win", "loss", "draw", "abandoned"].includes(String(outcome)) ||
        !Array.isArray(collections) || collections.length > 512 ||
        !collections.every((id) => typeof id === "string" && /^(orb_(0[0-9]|1[01])|secret_404)$/.test(id))) {
      return json(400, { error: "invalid_match_result" });
    }
    const { error } = await admin.rpc("oxenwar_apply_server_result", {
      p_user_id: session.userId,
      p_score: score,
      p_xp: xp,
      p_collection_ids: collections,
      p_kills: kills,
      p_deaths: deaths,
      p_damage_dealt: damage_dealt,
      p_shots_fired: shots_fired,
      p_shots_hit: shots_hit,
      p_playtime_seconds: playtime_seconds,
      p_outcome: outcome,
    });
    if (error) return json(500, { error: "result_persistence_failed" });
    return json(200, { ok: true });
  }

  return json(400, { error: "unknown_action" });
});
