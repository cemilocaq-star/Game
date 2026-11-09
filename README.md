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
- Procedural first-person Aether Blaster model, original synthesized sci-fi pulse sound, short energy trail, desktop/mobile fire input, and server-validated multiplayer hit scoring.
- Server-authoritative health: players start with 100 HP, each confirmed pulse hit deals 34 damage, zero HP triggers a 4-second K.O. state, then automatic full-health respawn; a final hit grants a bonus score.
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
- Left mouse button / mobile PULSE: fire the Aether Blaster
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


## Emotes
Players can trigger the original Griddy dance with **B** or the mobile **GRIDDY** button, and a goofy dance with **N** or **GOOFY**. Emotes animate the character while normal movement continues; selecting the same emote again stops it. Griddy plays a short, original synthesized looping beat. Emote state is replicated in multiplayer snapshots so other players can see the dance. No third-party dance audio or character animation assets are bundled.
