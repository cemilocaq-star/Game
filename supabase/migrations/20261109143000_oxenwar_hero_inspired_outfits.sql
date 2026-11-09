-- Original hero-inspired cosmetic outfits for OxenWar.
-- These are newly modeled silhouettes, not imported Marvel character assets.
insert into public.cosmetic_catalog (id, slot, name_key, color_hex, is_free) values
  ('outfit_iron_vanguard', 'outfit', 'cosmetic.outfit.iron_vanguard', '#A92332', true),
  ('outfit_web_sentinel', 'outfit', 'cosmetic.outfit.web_sentinel', '#B52D3D', true)
on conflict (id) do nothing;

-- Existing accounts receive the same free starter outfits as newly registered users.
insert into public.player_cosmetics (user_id, cosmetic_id)
select users.id, catalog.id
from auth.users as users
cross join public.cosmetic_catalog as catalog
where catalog.id in ('outfit_iron_vanguard', 'outfit_web_sentinel')
on conflict (user_id, cosmetic_id) do nothing;
