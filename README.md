# OxenWar

OxenWar is a free-to-play Godot 4.4.1 parkour arena project. Its visual direction uses a dark competitive-game layout with teal accents; it is inspired by modern shooter menus without copying another game's assets or interface.

## Current features

- Godot 4.4.1 parkour arena, server-owned movement physics, dash, slide, collectibles, rounds and gameplay events.
- Supabase email/password accounts; Supabase Auth verifies the player's token over HTTPS and issues a one-time game ticket; the dedicated server redeems that ticket before spawning a player.
- Friend search, friend requests, friend list and online presence.
- Private friend rooms with six-character join codes; private-room joins are checked against the Supabase friendship table.
- Public quick-match rooms, lobby roster and 8-player room capacity.
- 30-second reconnect reservation for a disconnected player.
- Server-owned score, XP awards, collectible inventory and event timers.
- Event-specific procedural 3D centerpieces, animated particles, original synthesized motifs, and hash-verified CC0 event cues/music.
- Local 3D footsteps with distinct generated sound profiles for stone, wood, metal, grass, dirt and ice; surfaces can be identified by `surface_type` metadata or `surface_<type>` groups.
- Eight selectable arcade weapon archetypes: Aether Blaster, MiniCore rapid pulse, Nova Hand Cannon, Pulse Carbine, Star Piercer, Duck Launcher, Banana Boomerang and Confetti Cannon. Their visuals and balance are intentionally fictional/arcade-style rather than realistic firearm replicas.
- Weapon selection is server-authoritative; desktop keys 1–8 or E/R cycle, with mobile WEAPON + / WEAPON - controls. All weapon hit validation and damage remain server-owned, and kill feed reports the selected weapon.
- Server-authoritative health: players start with 100 HP, each confirmed pulse hit deals 34 damage, zero HP triggers a 4-second K.O. state, then automatic full-health respawn; a final hit grants a bonus score.
- Consecutive-kill streaks are tracked by the server, reset when eliminated, and award milestone score bonuses at 3, 5, 7 and 10 kills with live HUD announcements.
- Weapon mastery is awarded by the game server from accepted combat events. Match XP is synced through the authenticated server-sync function into `player_weapon_mastery`; the Career Stats page reads persistent Aether Blaster and Grenade totals and shows Recruit/Bronze/Silver/Gold progression (100/300/600 XP). The migration `20261109193000_oxenwar_weapon_mastery.sql` and updated `oxenwar-server-sync` Edge Function must be deployed before hosted persistence works. Weapon skin unlock/equip is not yet implemented.
- Free-for-all and Team Deathmatch room modes. Team assignment is server-owned, with team spawns, team HUD colours and friendly-fire protection.
- Server-simulated grenades with a 2.5-second fuse, 5-metre blast radius, distance-scaled damage, cooldown validation and replicated projectile/explosion visuals.
- Original Dust II-inspired desert three-lane map blockout (A Long/site, Mid, connector and B site) built from procedural geometry; no Valve assets are copied.
- Match results are persisted through a Supabase Edge Function using one-time HMAC game tickets and a server-only session/secret.
- Free starter cosmetics plus two original hero-inspired outfits: Iron Vanguard (red/gold armored hero) and Web Sentinel (red/blue masked agility hero); outfit selection uses the existing character customization tab and is replicated to remote players.
- Azerbaijani, English, Turkish and Russian menu localization.
- Admin role is read-only from the client and must be assigned through trusted database administration.

## Supabase project

Project ref: `lznnfwhlsquiitkhjzlc`  
Region: `eu-central-1` (Frankfurt)  
API URL: `https://lznnfwhlsquiitkhjzlc.supabase.co`

The game client contains only the project's publishable key. Never add a Supabase secret/service-role key to the game or repository. RLS protects the stats and collection tables; players can read only their own rows. Writes are restricted to the server-only result function.

Database schema source is in `supabase/migrations/`. Apply all new migrations, including `20261109143000_oxenwar_hero_inspired_outfits.sql`, before using the new outfits on a hosted Supabase project. The server sync Edge Function is in `supabase/functions/oxenwar-server-sync/index.ts`. It validates user JWTs over HTTPS when issuing a 60-second, single-use game ticket; the game server redeems it and receives a 12-hour server-only session token.

## Run locally

1. Install Godot 4.4.1 Standard (not .NET) and Python 3.
2. From the repository root, run `python3 tools/fetch_open_audio_assets.py` (on Windows, `py tools/fetch_open_audio_assets.py`). The script downloads the CC0 audio files and verifies each SHA-256 hash.
3. Open `project.godot`.
4. Run `main.tscn`.
5. Register/sign in with Supabase.
6. Run a dedicated server in another terminal: `godot --headless --path . -- --server`.
7. In the game, enter the server's LAN address or public hostname and press **CONNECT**.
8. Choose **FREE FOR ALL** or **TEAM DEATHMATCH** in the in-game mode selector. Use **CREATE ROOM** to make a private friend room, **JOIN** with its code, or **QUICK MATCH** to enter a public room of the selected mode. The current arena is the original Dust II-inspired desert blockout.

For a private room, share its six-character code with an existing OxenWar friend. The server checks the friendship relationship before allowing entry. Public quick-match rooms are available to all authenticated players.

## Controls

- WASD / arrows: move
- Mouse: look
- Space: jump
- Shift: sprint
- Ctrl: slide
- Q: dash
- Left mouse button / mobile PULSE: fire the selected arcade weapon
- Number keys 1–8: select a weapon; E / R: cycle forward/backward (mobile has WEAPON + / WEAPON -)
- G: throw a server-simulated grenade
- Escape: release/capture mouse

Online clients send input only. The server runs CharacterBody3D movement and collision against its own arena, and sends authoritative snapshots back to clients.

## Builds

GitHub Actions validates the structure, imports/parses the project with Godot headless, starts a dedicated-server smoke test, and attempts Windows x86_64 EXE and Android arm64 debug APK exports. Artifacts are only considered built when the workflow succeeds and the files are uploaded.

- Windows: `build/OxenWar.exe`
- Android: `build/OxenWar.apk`

## Important limitations

- The server code and Supabase database/Edge Function are deployed in the repository/project, but **no public game server instance has been launched yet**. The Fly.io configuration is a template until the owner deploys it.
- Multiplayer authentication and match-result persistence require the same `OXENWAR_SERVER_SECRET` in Supabase Edge Function secrets and the game-server host environment. Without it, the secure ticket handshake is disabled. Do not put this secret in the client or GitHub.
- Rooms and active matches are held in server memory. Reconnect reservations last 30 seconds; a server process restart ends active rooms.
- Match results are written at match completion, room leave, or reconnect-reservation expiry. An unexpected host shutdown before one of those points can lose the in-progress match.
- Online friends can be invited by username from the in-game lobby; the invite sends a private room code. Offline friends can join later using the shared code.
- Godot CI parsing/export and live multi-device tests must pass before calling the complete game runtime production-ready.

## Security

- Never commit a secret/service-role key.
- Keep RLS enabled on every exposed table.
- Supabase Auth validates the player's JWT; the server never trusts a client-provided user ID or display name.
- The server owns movement, collision, scores, XP, event timing and collectible awards. Never re-enable client-side online movement or score awards.


## Visual quality pass

The client arena receives a lightweight procedural art-detail pass with floor inlays, perimeter trims, site markers, corner beacon housings and quality-scaled fill lights. The shared surface shader adds subtle procedural material variation, while the graphics manager applies filmic tonemapping, color grading and quality-scaled glow/fog. These are visual-only additions; the dedicated server skips the art-detail pass and collision/gameplay geometry is unchanged.

## Character model detail pass
The local player and replicated remote-player proxies now share a lightweight procedural equipment model: helmet/visor, layered vest and chest plate, shoulder pads, sleeves, forearm guards, gloves, utility belt and pouches, separate leg and knee pieces, boots, backpack and small accent panels. Outfit palettes are derived from the selected cosmetic, with dedicated Iron Vanguard and Web Sentinel colors. The detail meshes are visual-only, sit inside the existing movement capsule, and are hidden while the beach outfit is active. This pass does not add a skeletal rig, motion-captured animation, or change collision and server movement.

## Aether Blaster detail pass
The Aether Blaster retains its original procedural model. The selectable arcade weapon registry now adds distinct server-validated damage/cooldown/range profiles and color-coded impact effects for each fictional archetype. Duck Launcher, Banana Boomerang and Confetti Cannon use intentionally silly visual impact cues. Weapon models are currently represented by the shared first-person device; unique first-person meshes and per-weapon mastery are follow-up work.

## Combat visual effects pass
Grenade detonations now use a client-only layered effect with an expanding shock ring, short orange light flash, rising smoke puffs and outward sparks. Remote Aether Blaster impacts receive a brief cyan energy flash and ring at the reported endpoint. These effects are cosmetic only: authoritative grenade movement, blast radius, damage, hit validation and score logic remain on the server.

## Character movement animation pass
Local and remote characters now share a lightweight procedural limb rig with separate arm and leg pivots. The rig animates alternating arm/leg swings while moving, a restrained idle breathing/bob motion, and a forward-lean pose while sliding. Existing CharacterBody3D movement, collision shapes, server input simulation and network snapshots are unchanged. This is procedural animation, not a skeletal/retargeted animation asset.

## Beach / swimwear

The arena includes a shallow, non-blocking pool. Entering its marked swim zone switches the character to a modest beach outfit (shirt, swim shorts and sunglasses); leaving restores the regular appearance. The server derives the swim-zone state from player position and replicates it in snapshots so remote players see the same outfit. This is a visual zone only; it does not yet implement swimming physics or water movement.

## Emotes
Players can trigger the original Griddy dance with **B** or the mobile **GRIDDY** button, and a goofy dance with **N** or **GOOFY**. Emotes animate the character while normal movement continues; selecting the same emote again stops it. Griddy plays a short, original synthesized looping beat. Emote state is replicated in multiplayer snapshots so other players can see the dance. No third-party dance audio or character animation assets are bundled.

## HUD visual pass
The in-game HUD now uses restrained translucent panels for combat status, vitals and lobby controls, with cyan accent borders and custom health, stamina and XP progress-bar styling. The health label changes to a warning tint at low health. HUD presentation is client-side only; gameplay values and authoritative state are unchanged.

## Kill feed and match scoreboard
Confirmed eliminations now generate a reliable server-authored kill-feed event for every room member, identifying the killer, victim and weapon type (Aether Blaster or grenade). The server tracks deaths alongside kills and includes both in authoritative snapshots. The client displays the five most recent elimination notices and a live scoreboard sorted by kills, then score, with K/D/score columns. Press **Tab** on desktop or use the **SCOREBOARD** touch button on mobile. These UI elements do not award kills or alter combat authority.

## Match results and combat statistics
The server now records accepted Aether Blaster shots, confirmed hits, damage dealt and damage received, and replicates these fields in authoritative player snapshots. The match-results overlay shows the local player's K/D, score, weapon accuracy, damage dealt/received, a ranked top-five table and an MVP selected by score (kills break ties). Team Deathmatch additionally reports red/blue team kill totals and the winning side or a draw. Accuracy is specifically blaster hit rate; grenade damage is included in damage totals but not in the weapon accuracy denominator.

## Career profile and persistent statistics
The authenticated profile menu now has a Career Statistics tab. It reads the player's own aggregate row from `player_stats` and displays matches, wins/losses/draws, total kills/deaths, K/D, server-recorded weapon accuracy, best score, best kills, best damage, total damage and accumulated playtime. Match outcomes and combat totals are submitted only by the dedicated server through the signed server-session endpoint; the client has read-only access under the existing RLS policy. Apply migration `20261109170000_oxenwar_career_statistics.sql` and redeploy the `oxenwar-server-sync` Edge Function before expecting career totals to update. Abandoned sessions count as matches played but do not increment win/loss/draw totals.

## XP rank progression
The Career Statistics tab derives a player's rank directly from the existing server-persisted `total_xp` field; no second XP wallet or client-side rank writes are introduced. Thresholds are Bronze (0), Silver (500), Gold (1,500), Platinum (3,500), Diamond (7,000) and Master (12,000). The profile shows the current rank, XP progress toward the next tier and remaining XP. Rank labels are localized in Azerbaijani, English, Turkish and Russian. The rank is a display tier, not a separate competitive matchmaking rating.

## Match XP reward and rank-up presentation
The server snapshot now includes the authoritative per-match XP total. The results overlay shows XP earned, career XP, the rank badge and progress bar, and animates the card when a rank threshold is crossed. Offline orb and secret rewards are counted in the local match summary as well. Online rank progress uses server-synchronized career XP; clients cannot award themselves online XP.

## King of the Hill mode
A third multiplayer mode, King of the Hill, assigns players to balanced red/blue teams. The dedicated server tracks players inside the central capture zone, pauses capture while contested, awards control points while one team holds the zone, and determines match outcomes from objective control time. Capture progress and team totals are replicated to the HUD; the arena marks the central objective with a luminous boundary. Capture and scoring are server-authoritative.
