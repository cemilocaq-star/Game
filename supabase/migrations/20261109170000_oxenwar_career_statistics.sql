alter table public.player_stats
  add column if not exists total_kills bigint not null default 0 check (total_kills >= 0),
  add column if not exists total_deaths bigint not null default 0 check (total_deaths >= 0),
  add column if not exists matches_won integer not null default 0 check (matches_won >= 0),
  add column if not exists matches_lost integer not null default 0 check (matches_lost >= 0),
  add column if not exists matches_drawn integer not null default 0 check (matches_drawn >= 0),
  add column if not exists best_kills integer not null default 0 check (best_kills >= 0),
  add column if not exists best_damage numeric(14,2) not null default 0 check (best_damage >= 0),
  add column if not exists total_damage_dealt numeric(16,2) not null default 0 check (total_damage_dealt >= 0),
  add column if not exists total_shots_fired bigint not null default 0 check (total_shots_fired >= 0),
  add column if not exists total_shots_hit bigint not null default 0 check (total_shots_hit >= 0),
  add column if not exists total_playtime_seconds bigint not null default 0 check (total_playtime_seconds >= 0);

drop function if exists public.oxenwar_apply_server_result(uuid, integer, integer, text[]);

create function public.oxenwar_apply_server_result(
  p_user_id uuid,
  p_score integer,
  p_xp integer,
  p_collection_ids text[],
  p_kills integer,
  p_deaths integer,
  p_damage_dealt numeric,
  p_shots_fired integer,
  p_shots_hit integer,
  p_playtime_seconds integer,
  p_outcome text
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
  if p_user_id is null or p_score < 0 or p_score > 20000 or p_xp < 0 or p_xp > 50000
    or p_kills < 0 or p_kills > 5000 or p_deaths < 0 or p_deaths > 5000
    or p_damage_dealt < 0 or p_damage_dealt > 10000000
    or p_shots_fired < 0 or p_shots_fired > 20000 or p_shots_hit < 0 or p_shots_hit > p_shots_fired
    or p_playtime_seconds < 0 or p_playtime_seconds > 7200
    or p_outcome not in ('win','loss','draw','abandoned')
    or cardinality(coalesce(p_collection_ids, array[]::text[])) > 512 then
    raise exception 'invalid match result';
  end if;
  insert into public.player_stats(
    user_id, total_score, best_score, total_xp, matches_played,
    total_kills, total_deaths, matches_won, matches_lost, matches_drawn,
    best_kills, best_damage, total_damage_dealt, total_shots_fired,
    total_shots_hit, total_playtime_seconds, updated_at
  ) values (
    p_user_id, p_score, p_score, p_xp, 1,
    p_kills, p_deaths,
    case when p_outcome = 'win' then 1 else 0 end,
    case when p_outcome = 'loss' then 1 else 0 end,
    case when p_outcome = 'draw' then 1 else 0 end,
    p_kills, p_damage_dealt, p_damage_dealt, p_shots_fired,
    p_shots_hit, p_playtime_seconds, now()
  )
  on conflict (user_id) do update set
    total_score = public.player_stats.total_score + excluded.total_score,
    best_score = greatest(public.player_stats.best_score, excluded.best_score),
    total_xp = public.player_stats.total_xp + excluded.total_xp,
    matches_played = public.player_stats.matches_played + 1,
    total_kills = public.player_stats.total_kills + excluded.total_kills,
    total_deaths = public.player_stats.total_deaths + excluded.total_deaths,
    matches_won = public.player_stats.matches_won + excluded.matches_won,
    matches_lost = public.player_stats.matches_lost + excluded.matches_lost,
    matches_drawn = public.player_stats.matches_drawn + excluded.matches_drawn,
    best_kills = greatest(public.player_stats.best_kills, excluded.best_kills),
    best_damage = greatest(public.player_stats.best_damage, excluded.best_damage),
    total_damage_dealt = public.player_stats.total_damage_dealt + excluded.total_damage_dealt,
    total_shots_fired = public.player_stats.total_shots_fired + excluded.total_shots_fired,
    total_shots_hit = public.player_stats.total_shots_hit + excluded.total_shots_hit,
    total_playtime_seconds = public.player_stats.total_playtime_seconds + excluded.total_playtime_seconds,
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

revoke all on function public.oxenwar_apply_server_result(uuid, integer, integer, text[], integer, integer, numeric, integer, integer, integer, text) from public, anon, authenticated;
grant execute on function public.oxenwar_apply_server_result(uuid, integer, integer, text[], integer, integer, numeric, integer, integer, integer, text) to service_role;
