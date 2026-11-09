create table if not exists public.oxenwar_username_auth_limits (
  key_hash text primary key check (key_hash ~ '^[0-9a-f]{64}$'),
  window_started_at timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0)
);
alter table public.oxenwar_username_auth_limits enable row level security;
revoke all on public.oxenwar_username_auth_limits from public, anon, authenticated;
grant all on public.oxenwar_username_auth_limits to service_role;

create or replace function public.oxenwar_consume_username_auth_attempt(
  p_key_hash text,
  p_max_attempts integer,
  p_window_seconds integer
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_attempts integer;
begin
  if p_key_hash !~ '^[0-9a-f]{64}$' or p_max_attempts < 1 or p_window_seconds < 1 then
    return false;
  end if;
  insert into public.oxenwar_username_auth_limits(key_hash, window_started_at, attempts)
  values (p_key_hash, now(), 1)
  on conflict (key_hash) do update
    set attempts = case
      when public.oxenwar_username_auth_limits.window_started_at < now() - make_interval(secs => p_window_seconds) then 1
      else public.oxenwar_username_auth_limits.attempts + 1
    end,
    window_started_at = case
      when public.oxenwar_username_auth_limits.window_started_at < now() - make_interval(secs => p_window_seconds) then now()
      else public.oxenwar_username_auth_limits.window_started_at
    end
  returning attempts into current_attempts;
  return current_attempts <= p_max_attempts;
end;
$$;
revoke all on function public.oxenwar_consume_username_auth_attempt(text, integer, integer) from public, anon, authenticated;
grant execute on function public.oxenwar_consume_username_auth_attempt(text, integer, integer) to service_role;

create or replace function public.oxenwar_lookup_auth_email(p_username text)
returns text
language sql
security definer
set search_path = ''
stable
as $$
  select u.email
  from auth.users u
  join public.profiles p on p.id = u.id
  where lower(p.username) = lower(btrim(p_username))
  limit 1;
$$;
revoke all on function public.oxenwar_lookup_auth_email(text) from public, anon, authenticated;
grant execute on function public.oxenwar_lookup_auth_email(text) to service_role;
