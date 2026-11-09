alter table public.friend_requests
  drop constraint if exists friend_requests_unique_direction;

create unique index if not exists friend_requests_one_pending_pair_idx
  on public.friend_requests (least(sender_id, receiver_id), greatest(sender_id, receiver_id))
  where status = 'pending';

create index if not exists friend_requests_receiver_created_idx
  on public.friend_requests (receiver_id, created_at desc);
create index if not exists friendships_user_b_idx
  on public.friendships (user_b);
create index if not exists player_cosmetics_cosmetic_id_idx
  on public.player_cosmetics (cosmetic_id);
create index if not exists profiles_accessory_id_idx
  on public.profiles (accessory_id);
create index if not exists profiles_avatar_color_id_idx
  on public.profiles (avatar_color_id);
create index if not exists profiles_outfit_id_idx
  on public.profiles (outfit_id);

create or replace function private.handle_new_oxenwar_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_username text;
begin
  requested_username := nullif(btrim(new.raw_user_meta_data ->> 'username'), '');

  if requested_username is null
     or requested_username !~ '^[A-Za-z0-9_]{3,20}$'
     or exists (
       select 1 from public.profiles p
       where lower(p.username) = lower(requested_username)
     ) then
    requested_username := 'player_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    requested_username,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Player')
  )
  on conflict (id) do nothing;

  insert into public.player_roles (user_id, role)
  values (new.id, 'player')
  on conflict (user_id) do nothing;

  insert into public.player_cosmetics (user_id, cosmetic_id)
  select new.id, c.id
  from public.cosmetic_catalog c
  where c.is_free
  on conflict do nothing;

  insert into public.online_presence (user_id, last_seen_at)
  values (new.id, now())
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function private.handle_new_oxenwar_user() from public, anon, authenticated;
