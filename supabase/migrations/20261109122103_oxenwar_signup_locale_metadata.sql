create or replace function private.handle_new_oxenwar_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_username text;
  requested_locale text;
begin
  requested_username := nullif(btrim(new.raw_user_meta_data ->> 'username'), '');
  requested_locale := coalesce(new.raw_user_meta_data ->> 'locale', 'en');

  if requested_username is null
     or requested_username !~ '^[A-Za-z0-9_]{3,20}$'
     or exists (
       select 1 from public.profiles p
       where lower(p.username) = lower(requested_username)
     ) then
    requested_username := 'player_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  if requested_locale not in ('az', 'en', 'tr', 'ru') then
    requested_locale := 'en';
  end if;

  insert into public.profiles (id, username, display_name, locale)
  values (
    new.id,
    requested_username,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Player'),
    requested_locale
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
