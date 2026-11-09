import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

async function hashKey(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function validUsername(value: string): boolean {
  return /^[A-Za-z0-9_]{3,20}$/.test(value);
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });

  let body: Record<string, unknown>;
  try {
    if (Number(request.headers.get("content-length") ?? "0") > 4096) return json(413, { error: "request_too_large" });
    body = await request.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }

  const action = String(body.action ?? "");
  const username = String(body.username ?? "").trim();
  const password = String(body.password ?? "");
  const displayName = String(body.display_name ?? "").trim();
  const locale = ["az", "en", "tr", "ru"].includes(String(body.locale)) ? String(body.locale) : "en";

  if (!["login", "register"].includes(action) || !validUsername(username) ||
      password.length < 8 || password.length > 128 ||
      (action === "register" && (!displayName || displayName.length > 40))) {
    return json(400, { error: "invalid_credentials_format" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey || !anonKey) return json(503, { error: "auth_service_unavailable" });

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const ip = (request.headers.get("x-forwarded-for") ?? request.headers.get("x-real-ip") ?? "unknown").split(",")[0].trim();
  const rateKey = await hashKey([action, ip, username.toLowerCase()].join("|"));
  const { data: allowed, error: rateError } = await admin.rpc("oxenwar_consume_username_auth_attempt", {
    p_key_hash: rateKey,
    p_max_attempts: action === "register" ? 4 : 8,
    p_window_seconds: action === "register" ? 3600 : 900,
  });
  if (rateError || allowed !== true) return json(429, { error: "too_many_attempts" });

  let authEmail = "";
  if (action === "register") {
    const { data: existingEmail, error: lookupError } = await admin.rpc("oxenwar_lookup_auth_email", {
      p_username: username,
    });
    if (lookupError) return json(503, { error: "auth_service_unavailable" });
    if (existingEmail) return json(409, { error: "username_unavailable" });

    authEmail = username.toLowerCase() + "@accounts.oxenwar.invalid";
    const { error: createError } = await admin.auth.admin.createUser({
      email: authEmail,
      password,
      email_confirm: true,
      user_metadata: { username, display_name: displayName, locale },
    });
    if (createError) return json(409, { error: "username_unavailable_or_registration_failed" });
  } else {
    const { data: foundEmail, error: lookupError } = await admin.rpc("oxenwar_lookup_auth_email", {
      p_username: username,
    });
    if (lookupError) return json(503, { error: "auth_service_unavailable" });
    authEmail = typeof foundEmail === "string" ? foundEmail : "";
    if (!authEmail) return json(401, { error: "invalid_username_or_password" });
  }

  const client = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await client.auth.signInWithPassword({ email: authEmail, password });
  if (error || !data.session || !data.user) {
    return json(action === "login" ? 401 : 503, {
      error: action === "login" ? "invalid_username_or_password" : "account_created_but_sign_in_failed",
    });
  }

  return json(200, {
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
    expires_in: data.session.expires_in,
    user: { id: data.user.id },
  });
});
