-- Server directory: dedicated servers register themselves, clients find a server (or the server that
-- hosts a room code) without typing an address. Only the oxenwar-server-sync Edge Function writes;
-- signed-in players can only call the two read functions below.

create table if not exists public.oxenwar_servers (
  host text primary key check (char_length(host) between 3 and 200),
  player_count integer not null default 0 check (player_count >= 0),
  max_players integer not null default 32 check (max_players between 1 and 1000),
  updated_at timestamptz not null default now()
);

create table if not exists public.oxenwar_room_directory (
  code text primary key check (code ~ '^[A-Z2-9]{6}$'),
  server_host text not null references public.oxenwar_servers(host) on delete cascade,
  mode text not null default 'ffa',
  map_index integer not null default 4 check (map_index between 0 and 20),
  updated_at timestamptz not null default now()
);

create index if not exists oxenwar_room_directory_server_idx on public.oxenwar_room_directory (server_host);

alter table public.oxenwar_servers enable row level security;
alter table public.oxenwar_room_directory enable row level security;
revoke all on public.oxenwar_servers from anon, authenticated;
revoke all on public.oxenwar_room_directory from anon, authenticated;

-- Best server to join. A server that reported in the last 90 seconds and is not full wins (fuller
-- first, so players gather in one place). If none is fresh, the most recently seen server (within 7
-- days) is returned with stale=true so the client can wake a sleeping free-tier host.
create or replace function public.oxenwar_find_server()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select jsonb_build_object(
      'host', host,
      'player_count', player_count,
      'max_players', max_players,
      'stale', updated_at <= now() - interval '90 seconds')
    from public.oxenwar_servers
    where updated_at > now() - interval '7 days'
      and (updated_at <= now() - interval '90 seconds' or player_count < max_players)
    order by (updated_at > now() - interval '90 seconds') desc, player_count desc, updated_at desc
    limit 1
  ), 'null'::jsonb);
$$;

-- Server that currently hosts a room code. Only fresh servers count: rooms live in server memory.
create or replace function public.oxenwar_find_room_server(p_code text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select jsonb_build_object('host', d.server_host, 'mode', d.mode, 'map_index', d.map_index)
    from public.oxenwar_room_directory d
    join public.oxenwar_servers s on s.host = d.server_host
    where d.code = upper(btrim(p_code))
      and s.updated_at > now() - interval '90 seconds'
    limit 1
  ), 'null'::jsonb);
$$;

revoke all on function public.oxenwar_find_server() from public, anon;
revoke all on function public.oxenwar_find_room_server(text) from public, anon;
grant execute on function public.oxenwar_find_server() to authenticated;
grant execute on function public.oxenwar_find_room_server(text) to authenticated;
