alter table public.profiles
  add column if not exists accessory_id text references public.cosmetic_catalog(id);

create or replace function private.validate_oxenwar_profile_cosmetics()
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
  if new.accessory_id is not null and not exists (
    select 1 from public.player_cosmetics pc join public.cosmetic_catalog cc on cc.id = pc.cosmetic_id
    where pc.user_id = new.id and pc.cosmetic_id = new.accessory_id and cc.slot = 'accessory'
  ) then raise exception 'Accessory is not unlocked for this player'; end if;
  return new;
end;
$$;
