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
- Match results are persisted through a Supabase Edge Function using one-time HMAC game tickets and a server-only session/secret.
- Free starter cosmetics and Azerbaijani, English, Turkish and Russian menu localization.
- Admin role is read-only from the client and must be assigned through trusted database administration.

## Supabase project

Project ref: `lznnfwhlsquiitkhjzlc`  
Region: `eu-central-1` (Frankfurt)  
API URL: `https://lznnfwhlsquiitkhjzlc.supabase.co`

The game client contains only the project's publishable key. Never add a Supabase secret/service-role key to the game or repository. RLS protects the stats and collection tables; players can read only their own rows. Writes are restricted to the server-only result function.

Database schema source is in `supabase/migrations/`. The server sync Edge Function is in `supabase/functions/oxenwar-server-sync/index.ts`. It validates user JWTs over HTTPS when issuing a 60-second, single-use game ticket; the game server redeems it and receives a 12-hour server-only session token.

## Run locally

1. Install Godot 4.4.1 Standard (not .NET) and Python 3.
2. From the repository root, run `python3 tools/fetch_open_audio_assets.py` (on Windows, `py tools/fetch_open_audio_assets.py`). The script downloads the CC0 audio files and verifies each SHA-256 hash.
3. Open `project.godot`.
4. Run `main.tscn`.
5. Register/sign in with Supabase.
6. Run a dedicated server in another terminal: `godot --headless --path . -- --server`.
7. In the game, enter the server's LAN address or public hostname and press **CONNECT**.
8. Use **CREATE ROOM** to make a private friend room, **JOIN** with its code, or **QUICK MATCH** to enter a public room.

For a private room, share its six-character code with an existing OxenWar friend. The server checks the friendship relationship before allowing entry. Public quick-match rooms are available to all authenticated players.

## Controls

- WASD / arrows: move
- Mouse: look
- Space: jump
- Shift: sprint
- Ctrl: slide
- Q: dash
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
