create schema if not exists private;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  display_name text not null default 'Player',
  locale text not null default 'en' check (locale in ('az','en','tr','ru')),
  avatar_color_id text,
  outfit_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (username ~ '^[A-Za-z0-9_]{3,20}$')
);
create unique index profiles_username_lower_uidx on public.profiles (lower(username));

create table public.cosmetic_catalog (
  id text primary key,
  slot text not null check (slot in ('avatar_color','outfit','accessory')),
  name_key text not null,
  color_hex text not null default '#FFFFFF' check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  is_free boolean not null default true check (is_free = true)
);

insert into public.cosmetic_catalog (id, slot, name_key, color_hex) values
 ('color_cyan','avatar_color','cosmetic.color.cyan','#27D7E7'),
 ('color_violet','avatar_color','cosmetic.color.violet','#9B70FF'),
 ('color_orange','avatar_color','cosmetic.color.orange','#FF9B42'),
 ('color_lime','avatar_color','cosmetic.color.lime','#A7E34B'),
 ('outfit_default','outfit','cosmetic.outfit.default','#DCE7F2'),
 ('outfit_runner','outfit','cosmetic.outfit.runner','#27D7E7'),
 ('outfit_neon','outfit','cosmetic.outfit.neon','#9B70FF'),
 ('accessory_cap','accessory','cosmetic.accessory.cap','#FF9B42'),
 ('accessory_headphones','accessory','cosmetic.accessory.headphones','#A7E34B');

alter table public.profiles
  add constraint profiles_avatar_color_id_fkey foreign key (avatar_color_id) references public.cosmetic_catalog(id),
  add constraint profiles_outfit_id_fkey foreign key (outfit_id) references public.cosmetic_catalog(id);

create table public.player_cosmetics (
  user_id uuid not null references auth.users(id) on delete cascade,
  cosmetic_id text not null references public.cosmetic_catalog(id) on delete restrict,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, cosmetic_id)
);
create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friend_requests_not_self check (sender_id <> receiver_id),
  constraint friend_requests_unique_direction unique (sender_id, receiver_id)
);
create table public.friendships (
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  constraint friendships_ordered check (user_a < user_b)
);
create table public.online_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_seen_at timestamptz not null default now()
);
create table public.player_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'player' check (role in ('player','admin')),
  created_at timestamptz not null default now()
);

create function private.handle_new_oxenwar_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (new.id, 'player_' || substr(replace(new.id::text, '-', ''), 1, 8),
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Player'))
  on conflict (id) do nothing;
  insert into public.player_roles (user_id, role) values (new.id, 'player') on conflict do nothing;
  insert into public.player_cosmetics (user_id, cosmetic_id)
    select new.id, id from public.cosmetic_catalog where is_free on conflict do nothing;
  insert into public.online_presence (user_id, last_seen_at) values (new.id, now()) on conflict do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created_oxenwar after insert on auth.users
for each row execute function private.handle_new_oxenwar_user();

create function private.validate_oxenwar_profile_cosmetics()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if new.avatar_color_id is not null and not exists (
    select 1 from public.player_cosmetics pc join public.cosmetic_catalog cc on cc.id = pc.cosmetic_id
    where pc.user_id = new.id and pc.cosmetic_id = new.avatar_color_id and cc.slot = 'avatar_color'
  ) then raise exception 'Avatar color is not unlocked for this player'; end if;
  if new.outfit_id is not null and not exists (
    select 1 from public.player_cosmetics pc join public.cosmetic_catalog cc on cc.id = pc.cosmetic_id
    where pc.user_id = new.id and pc.cosmetic_id = new.outfit_id and cc.slot = 'outfit'
  ) then raise exception 'Outfit is not unlocked for this player'; end if;
  return new;
end;
$$;
create trigger validate_oxenwar_profile_cosmetics before insert or update of avatar_color_id, outfit_id
on public.profiles for each row execute function private.validate_oxenwar_profile_cosmetics();

create function private.guard_friend_request()
returns trigger language plpgsql set search_path = ''
as $$
declare left_id uuid; right_id uuid;
begin
  if new.sender_id = new.receiver_id then raise exception 'You cannot add yourself'; end if;
  left_id := least(new.sender_id, new.receiver_id);
  right_id := greatest(new.sender_id, new.receiver_id);
  if exists (select 1 from public.friendships f where f.user_a = left_id and f.user_b = right_id) then
    raise exception 'Players are already friends';
  end if;
  if exists (
    select 1 from public.friend_requests fr
    where fr.status = 'pending'
      and ((fr.sender_id = new.sender_id and fr.receiver_id = new.receiver_id)
        or (fr.sender_id = new.receiver_id and fr.receiver_id = new.sender_id))
      and (tg_op = 'INSERT' or fr.id <> new.id)
  ) then raise exception 'A pending friend request already exists'; end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger guard_oxenwar_friend_request before insert or update on public.friend_requests
for each row execute function private.guard_friend_request();

create function private.create_oxenwar_friendship_on_accept()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if old.status = 'pending' and new.status = 'accepted' then
    insert into public.friendships (user_a, user_b)
    values (least(new.sender_id, new.receiver_id), greatest(new.sender_id, new.receiver_id))
    on conflict do nothing;
  end if;
  return new;
end;
$$;
create trigger create_oxenwar_friendship_on_accept after update of status on public.friend_requests
for each row execute function private.create_oxenwar_friendship_on_accept();

create function private.touch_oxenwar_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin new.updated_at := now(); return new; end;
$$;
create trigger touch_oxenwar_profile_updated_at before update on public.profiles
for each row execute function private.touch_oxenwar_updated_at();

alter table public.profiles enable row level security;
alter table public.cosmetic_catalog enable row level security;
alter table public.player_cosmetics enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.online_presence enable row level security;
alter table public.player_roles enable row level security;

create policy "Authenticated users can view profiles" on public.profiles
for select to authenticated using (true);
create policy "Players update their own profile" on public.profiles
for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy "Authenticated users view free cosmetics" on public.cosmetic_catalog
for select to authenticated using (is_free = true);
create policy "Players view own cosmetics" on public.player_cosmetics
for select to authenticated using ((select auth.uid()) = user_id);
create policy "Participants view friend requests" on public.friend_requests
for select to authenticated using ((select auth.uid()) in (sender_id, receiver_id));
create policy "Players send own friend requests" on public.friend_requests
for insert to authenticated with check ((select auth.uid()) = sender_id and status = 'pending');
create policy "Receivers respond to pending requests" on public.friend_requests
for update to authenticated using ((select auth.uid()) = receiver_id and status = 'pending')
with check ((select auth.uid()) = receiver_id and status in ('accepted','rejected'));
create policy "Senders cancel pending requests" on public.friend_requests
for delete to authenticated using ((select auth.uid()) = sender_id and status = 'pending');
create policy "Friends can view friendship rows" on public.friendships
for select to authenticated using ((select auth.uid()) in (user_a, user_b));
create policy "Friends can remove friendship" on public.friendships
for delete to authenticated using ((select auth.uid()) in (user_a, user_b));
create policy "Friends can view presence" on public.online_presence
for select to authenticated using (
  user_id = (select auth.uid()) or exists (
    select 1 from public.friendships f
    where (f.user_a = (select auth.uid()) and f.user_b = online_presence.user_id)
       or (f.user_b = (select auth.uid()) and f.user_a = online_presence.user_id)
  )
);
create policy "Players insert own presence" on public.online_presence
for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Players update own presence" on public.online_presence
for update to authenticated using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "Players view own role" on public.player_roles
for select to authenticated using ((select auth.uid()) = user_id);

grant select, update on public.profiles to authenticated;
grant select on public.cosmetic_catalog to authenticated;
grant select on public.player_cosmetics to authenticated;
grant select, insert, update, delete on public.friend_requests to authenticated;
grant select, delete on public.friendships to authenticated;
grant select, insert, update on public.online_presence to authenticated;
grant select on public.player_roles to authenticated;

revoke all on function private.handle_new_oxenwar_user() from public, anon, authenticated;
revoke all on function private.validate_oxenwar_profile_cosmetics() from public, anon, authenticated;
revoke all on function private.guard_friend_request() from public, anon, authenticated;
revoke all on function private.create_oxenwar_friendship_on_accept() from public, anon, authenticated;
revoke all on function private.touch_oxenwar_updated_at() from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'friend_requests') then
    alter publication supabase_realtime add table public.friend_requests;
  end if;
end $$;
