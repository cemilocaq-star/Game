create table public.player_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  total_score bigint not null default 0 check (total_score >= 0),
  best_score integer not null default 0 check (best_score >= 0),
  total_xp bigint not null default 0 check (total_xp >= 0),
  matches_played integer not null default 0 check (matches_played >= 0),
  updated_at timestamptz not null default now()
);

create table public.player_collections (
  user_id uuid not null references auth.users(id) on delete cascade,
  collection_id text not null check (collection_id ~ '^(orb_(0[0-9]|1[01])|secret_404)$'),
  quantity bigint not null default 0 check (quantity >= 0),
  first_collected_at timestamptz not null default now(),
  last_collected_at timestamptz not null default now(),
  primary key (user_id, collection_id)
);

alter table public.player_stats enable row level security;
alter table public.player_collections enable row level security;

create policy "Players read own stats" on public.player_stats
for select to authenticated using ((select auth.uid()) = user_id);
create policy "Players read own collections" on public.player_collections
for select to authenticated using ((select auth.uid()) = user_id);

grant select on public.player_stats to authenticated;
grant select on public.player_collections to authenticated;

create or replace function public.oxenwar_apply_server_result(
  p_user_id uuid,
  p_score integer,
  p_xp integer,
  p_collection_ids text[]
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare collection_key text;
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
    raise exception 'server role required';
  end if;
  if p_user_id is null or p_score < 0 or p_score > 20000 or p_xp < 0 or p_xp > 50000 then
    raise exception 'invalid match result';
  end if;
  insert into public.player_stats(user_id, total_score, best_score, total_xp, matches_played, updated_at)
  values (p_user_id, p_score, p_score, p_xp, 1, now())
  on conflict (user_id) do update set
    total_score = public.player_stats.total_score + excluded.total_score,
    best_score = greatest(public.player_stats.best_score, excluded.best_score),
    total_xp = public.player_stats.total_xp + excluded.total_xp,
    matches_played = public.player_stats.matches_played + 1,
    updated_at = now();
  foreach collection_key in array coalesce(p_collection_ids, array[]::text[]) loop
    if collection_key !~ '^(orb_(0[0-9]|1[01])|secret_404)$' then
      raise exception 'invalid collection id';
    end if;
    insert into public.player_collections(user_id, collection_id, quantity)
    values (p_user_id, collection_key, 1)
    on conflict (user_id, collection_id) do update set
      quantity = public.player_collections.quantity + 1,
      last_collected_at = now();
  end loop;
end;
$$;

revoke all on function public.oxenwar_apply_server_result(uuid, integer, integer, text[]) from public, anon, authenticated;
grant execute on function public.oxenwar_apply_server_result(uuid, integer, integer, text[]) to service_role;
