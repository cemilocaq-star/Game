# OxenWar

OxenWar is a free-to-play Godot 4.4.1 parkour arena project. Its visual direction uses a dark competitive-game layout with teal accents; it is inspired by modern shooter menus without copying another game's assets or interface.

## Current features

- Existing local parkour arena, movement, dash, slide, collectibles, rounds, events, XP progression and graphics presets.
- Supabase email/password account registration and sign-in.
- Unique player usernames and display names.
- Friend search, outgoing/incoming friend requests, accept/reject and friend list.
- Friend online status based on a 30-second heartbeat and a 90-second online window.
- Free starter cosmetics: avatar colors, outfit variants and accessories.
- Azerbaijani, English, Turkish and Russian menu localization.
- Admin role is read-only from the client and must be assigned through trusted database administration; a player cannot grant themselves admin access.

## Supabase project

Project ref: `lznnfwhlsquiitkhjzlc`  
Region: `eu-central-1` (Frankfurt)  
API URL: `https://lznnfwhlsquiitkhjzlc.supabase.co`

The client uses the project's **publishable** key. This key is designed for client applications; access is restricted by database Row Level Security. Never add a Supabase secret/service-role key to the game or repository.

Database schema source is in `supabase/migrations/`. The tables use RLS. New Auth users receive a profile, player role, presence row and the free starter cosmetic inventory.

## Run locally

1. Install Godot 4.4.1 Standard (not .NET).
2. Open `project.godot`.
3. Run `main.tscn`.
4. Register with an email and password. If email confirmation is enabled in Supabase Auth, confirm the email before signing in.
5. Choose a language, find friends by username and equip free cosmetics.

## Controls

- WASD / arrows: move
- Mouse: look
- Space: jump
- Shift: sprint
- Ctrl: slide
- Q: dash
- Escape: release/capture mouse

## Builds

GitHub Actions validates the structure, imports/parses the project with Godot headless, and attempts Windows x86_64 EXE and Android arm64 debug APK exports. Artifacts are only considered built when the workflow succeeds and the files are uploaded.

- Windows: `build/OxenWar.exe`
- Android: `build/OxenWar.apk`

## Important limitations — read before calling this multiplayer

- The current parkour gameplay loop is still local single-player. Supabase currently provides online accounts, social graph, cosmetics and friend presence; it does **not** yet synchronize player movement, matches, rooms or combat between devices.
- Friend presence is heartbeat-based polling, not a continuous realtime indicator.
- Friend-request records are in the Realtime publication, but the game menu currently refreshes them when the Friends page is opened.
- Online admin role lookup is server-backed, but no player has been promoted to admin yet. Do not use the old client-side name/password gate as online security.
- Real device testing, Godot parse/build verification and live signup/friend-flow tests must be completed before a public release.

## Security

- Never commit a secret/service-role key.
- Keep RLS enabled on every exposed table.
- Do not trust client-side admin flags, player names, scores or movement for competitive multiplayer. Authoritative game logic requires a trusted game server.
