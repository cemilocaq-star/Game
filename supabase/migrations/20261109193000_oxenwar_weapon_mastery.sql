create table if not exists public.player_weapon_mastery (
  user_id uuid primary key references auth.users(id) on delete cascade,
  blaster_xp bigint not null default 0 check (blaster_xp >= 0),
  grenade_xp bigint not null default 0 check (grenade_xp >= 0),
  updated_at timestamptz not null default now()
);

alter table public.player_weapon_mastery enable row level security;
drop policy if exists "Players can read their own weapon mastery" on public.player_weapon_mastery;
create policy "Players can read their own weapon mastery"
  on public.player_weapon_mastery for select to authenticated
  using (auth.uid() = user_id);
revoke insert, update, delete on public.player_weapon_mastery from anon, authenticated;
grant select on public.player_weapon_mastery to authenticated;
grant all on public.player_weapon_mastery to service_role;

create or replace function public.oxenwar_apply_weapon_mastery(
  p_user_id uuid,
  p_blaster_xp integer,
  p_grenade_xp integer
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
    raise exception 'server role required';
  end if;
  if p_user_id is null or p_blaster_xp < 0 or p_blaster_xp > 100000
    or p_grenade_xp < 0 or p_grenade_xp > 100000 then
    raise exception 'invalid weapon mastery';
  end if;
  insert into public.player_weapon_mastery(user_id, blaster_xp, grenade_xp, updated_at)
  values (p_user_id, p_blaster_xp, p_grenade_xp, now())
  on conflict (user_id) do update set
    blaster_xp = public.player_weapon_mastery.blaster_xp + excluded.blaster_xp,
    grenade_xp = public.player_weapon_mastery.grenade_xp + excluded.grenade_xp,
    updated_at = now();
end;
$$;
revoke all on function public.oxenwar_apply_weapon_mastery(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.oxenwar_apply_weapon_mastery(uuid, integer, integer) to service_role;
