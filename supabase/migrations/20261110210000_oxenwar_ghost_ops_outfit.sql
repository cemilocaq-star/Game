-- Ghost-Ops Troll: a third signature troll outfit (balaclava, skull mask, tactical vest).
-- The Golden Pilot (outfit_runner) and Neon Cyan Riot (outfit_neon) trolls reuse the
-- existing catalog ids, so only the new Ghost-Ops outfit needs a catalog row.
insert into public.cosmetic_catalog (id, slot, name_key, color_hex, is_free) values
  ('outfit_ghost_ops', 'outfit', 'cosmetic.outfit.ghost_ops', '#1C1F22', true)
on conflict (id) do nothing;

-- Existing accounts receive the same free starter outfit as newly registered users
-- (the signup trigger already grants every is_free catalog row).
insert into public.player_cosmetics (user_id, cosmetic_id)
select users.id, 'outfit_ghost_ops'
from auth.users as users
on conflict (user_id, cosmetic_id) do nothing;
