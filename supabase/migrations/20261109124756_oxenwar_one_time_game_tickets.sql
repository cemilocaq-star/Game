create table public.oxenwar_game_tickets (
  jti uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  redeemed_at timestamptz,
  created_at timestamptz not null default now()
);
create index oxenwar_game_tickets_expiry_idx on public.oxenwar_game_tickets(expires_at);

create table public.oxenwar_server_sessions (
  session_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index oxenwar_server_sessions_user_idx on public.oxenwar_server_sessions(user_id, expires_at);

alter table public.oxenwar_game_tickets enable row level security;
alter table public.oxenwar_server_sessions enable row level security;
revoke all on public.oxenwar_game_tickets from public, anon, authenticated;
revoke all on public.oxenwar_server_sessions from public, anon, authenticated;
grant all on public.oxenwar_game_tickets to service_role;
grant all on public.oxenwar_server_sessions to service_role;
