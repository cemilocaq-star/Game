# OxenWar

OxenWar is a free-to-play Godot 4.4.1 parkour arena project. Its visual direction uses a dark competitive-game layout with teal accents; it is inspired by modern shooter menus without copying another game's assets or interface.

## Current features

- Godot 4.4.1 parkour arena, server-owned movement physics, dash, slide, collectibles, rounds and gameplay events.
- Username/password accounts with no user-facing email field. A server-only Edge Function maps usernames to Supabase Auth identities, creates accounts with a non-routable internal alias, applies database-backed attempt limits, and returns normal Supabase sessions. Existing email-based accounts can continue signing in with their existing password using their OxenWar username. Supabase Auth verifies the player's token over HTTPS and issues a one-time game ticket; the dedicated server redeems that ticket before spawning a player.
- Friend search, friend requests, friend list and online presence.
- Private friend rooms with six-character join codes; private-room joins are checked against the Supabase friendship table.
- Public quick-match rooms, lobby roster and 8-player room capacity.
- Dual networking transport: ENet over UDP for dedicated hosts, or WebSocket for hosted web services that expose HTTPS/WSS.
- 30-second reconnect reservation for a disconnected player.
- Server-owned score, XP awards, collectible inventory and event timers.
- Event-specific procedural 3D centerpieces, animated particles, original synthesized motifs, and hash-verified CC0 event cues/music.
- Local 3D footsteps with distinct generated sound profiles for stone, wood, metal, grass, dirt and ice; surfaces can be identified by `surface_type` metadata or `surface_<type>` groups.
- Twenty-seven selectable weapon archetypes: the original 23 arcade props plus Ranger Rifle, Heavy Sidearm, Longshot and Rotary Arc. The four additions are original, non-functional first-person game props with separate silhouettes, colors, synthetic audio and cosmetic impact styles.
- A scrollable 27-card Arsenal screen opens with V or the ARSENAL HUD button. Each of the 27 weapons has a dedicated procedural first-person 3D silhouette and color identity; E/R and mobile WEAPON + / WEAPON - cycle the full roster, while number keys 1–8 remain quick-select shortcuts. Equipping rebuilds the view model with a short transition; firing uses a weapon-specific synthetic pitch, and the server remains authoritative for selection, hit validation, cooldown, range and damage.
- Server-authoritative health: players start with 100 HP, each confirmed pulse hit deals 34 damage, zero HP triggers a 4-second K.O. state, then automatic full-health respawn; a final hit grants a bonus score.
- Consecutive-kill streaks are tracked by the server, reset when eliminated, and award milestone score bonuses at 3, 5, 7 and 10 kills with live HUD announcements.
- Weapon mastery is awarded by the game server from accepted combat events. Match XP is synced through the authenticated server-sync function into `player_weapon_mastery`; the Career Stats page reads persistent Aether Blaster and Grenade totals and shows Recruit/Bronze/Silver/Gold progression (100/300/600 XP). The migration `20261109193000_oxenwar_weapon_mastery.sql` and updated `oxenwar-server-sync` Edge Function must be deployed before hosted persistence works. Weapon skin unlock/equip is not yet implemented.
- Free-for-all and Team Deathmatch room modes. Team assignment is server-owned, with team spawns, team HUD colours and friendly-fire protection.
- Server-simulated grenades with a 2.5-second fuse, 5-metre blast radius, distance-scaled damage, cooldown validation and replicated projectile/explosion visuals.
- Seven themed procedural arena variants, including Sunken Oasis, Jungle Arena and Redstone Canyon. The new maps add sandstone courtyards, market stalls, palm trees, river bridges, temple ruins, a waterfall, canyon arches and lookout structures.
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
5. Register/sign in with an OxenWar username and password. Registration also asks for a display name; no email address is requested. Password recovery is not yet implemented, so players must keep their password safe.
6. Run a dedicated server in another terminal: `godot --headless --path . -- --server`.
7. In the game, enter the server's LAN address or public hostname and press **CONNECT**.
8. Choose **FREE FOR ALL** or **TEAM DEATHMATCH** in the in-game mode selector. Use **CREATE ROOM** to make a private friend room, **JOIN** with its code, or **QUICK MATCH** to enter a public room of the selected mode. The default arena is Sunken Oasis; an authorized admin can cycle through the available themed arenas.

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

- The server code and Supabase database/Edge Function are deployed in the repository/project, but **no public game server instance has been launched yet**. `fly.toml` is a UDP-host template; `render.yaml` is an optional WebSocket-host blueprint. Its HTTP health endpoint and WebSocket tunnel are provided by `server/render_entrypoint.py`; a live deployment and the shared server secret are still required.
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

The client arena uses a lightweight procedural environment builder with themed props and traversal pieces. Sunken Oasis adds sandstone halls, market awnings, palms, a fountain and rock gardens; Jungle Arena adds a swimmable river trench with a waterfall, a stepped pyramid and a ruined temple that mirror each other around the two energy sites, treehouses with rope bridges, log and stone crossings, flag bases, crates and jungle foliage; Redstone Canyon adds rock formations, an aqueduct walkway, caravan tents and a lookout. These are original low-poly procedural blockouts with collision on major structures, not finished AAA or imported production map assets.

## Character model detail pass
The local player, remote players and 3D customization preview now share the same original cartoon-troll detail model: rounded oversized heads, expressive eyes and brows, ears, cheeks, smiles, hair and outfit accents. Pilot/goggle, neon and other costume variations reuse the selected cosmetic outfit. The meshes are procedural low-poly visuals, not imported character assets; the existing movement capsule, server physics and network snapshots remain unchanged.

## Aether Blaster detail pass
The Aether Blaster retains its original procedural model. The selectable arcade weapon registry now adds distinct server-validated damage/cooldown/range profiles and color-coded impact effects for each fictional archetype. Duck Launcher, Banana Boomerang and Confetti Cannon use intentionally silly visual impact cues. Weapon models are currently represented by the shared first-person device; unique first-person meshes and per-weapon mastery are follow-up work.

## Combat visual effects pass
Grenade detonations now use a client-only layered effect with an expanding shock ring, short orange light flash, rising smoke puffs and outward sparks. Remote Aether Blaster impacts receive a brief cyan energy flash and ring at the reported endpoint. These effects are cosmetic only: authoritative grenade movement, blast radius, damage, hit validation and score logic remain on the server.

### Signature troll characters
Three original troll costumes are modeled procedurally (rounded primitives, no imported assets) and share the same head, limb rig and animation as every other outfit:

| Outfit id | Character | Highlights |
| --- | --- | --- |
| `outfit_runner` | Golden Pilot Troll | gold skin, brown bomber jacket with fleece collar, white scarf with trailing tails, leather aviator cap with brass goggles, olive shorts, bare feet |
| `outfit_ghost_ops` | Ghost-Ops Troll | pale skin, black balaclava hood and skull-print mask, tactical vest with pouches and shoulder radio, cargo shorts, mismatched pink/cyan flip-flops |
| `outfit_neon` | Neon Cyan Riot Troll | neon cyan skin, black riot armor with glowing trim, riot helmet with translucent visor, shoulder armor, left-side riot shield, knee pads |

`outfit_runner` and `outfit_neon` reuse the existing catalog ids, so their look changes for existing accounts without a database change. `outfit_ghost_ops` is a new catalog id: apply `20261110210000_oxenwar_ghost_ops_outfit.sql` to a hosted Supabase project before it appears in the customization tab. These three characters use a slimmer torso (`CharacterVisuals.apply_body_shape()`) so the oversized head, arms and legs are fully visible and the soles reach the ground line; the default and hero outfits keep the original capsule body. The beach swimwear overlay is still sized for the original capsule, so on the slim trolls it is not visible. Costume colors live in `CharacterVisuals.profile_for()`; the motion rig and the customization preview read the same table. The shield and other gear are cosmetic and add no collision or hitbox changes.

## Character movement animation pass
Local and remote characters share the articulated procedural limb rig. It animates alternating arm/leg swings, idle breathing, slide and emote poses; the troll head now adds a small movement-aware tilt/bounce during running, jumping, sliding and emotes. Existing CharacterBody3D movement, collision shapes, server input simulation and network snapshots are unchanged. This is procedural animation, not skeletal or motion-captured animation.

## Beach / swimwear

The previous beach/swim outfit visual remains in the codebase for compatibility, but the current themed arenas do not enable a dedicated swim trigger or swimming physics. Oasis water and jungle river surfaces are environmental scenery in this pass.

## Emotes
Players can trigger four distinct emotes: Griddy (**B** / mobile **GRIDDY**), Goofy (**N** / **GOOFY**), Robot (**M** / **ROBOT**) and Wave (**J** / **WAVE**). Each has a different procedural limb/body pattern; selecting the active emote again stops it and sends the stopped state to the server. The server replicates all four states to other players. Griddy retains its short original synthesized beat; no third-party dance audio or character animation assets are bundled.

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


## Expanded arcade arsenal and weapon presentation
The roster has 27 server-registered weapon archetypes plus the separate grenade throwable. Fifteen additions expand the range from crystal and orbit effects to bubbles, pixels, frost, solar energy, slime, moon discs and deliberately silly duck/chicken props. The client arsenal is a scrollable card grid; selecting a card changes the selected server weapon and rebuilds a distinct procedural first-person silhouette. These meshes are lightweight Godot primitives, not imported production weapon assets. Equip transition, existing firing recoil, colored beams and original synthesized shot audio are presentation effects only. The server continues to validate equipped IDs and combat values.


### Weapon inspect and sound pass
- Press **H** to inspect the equipped arcade weapon, or open the Arsenal and use **INSPECT [H]**. The inspect motion briefly presents the prop at an angle, then restores its first-person position; a subtle idle sway continues between actions.
- Each of the 27 weapons now has a separately synthesized original sound profile built from its own frequency/sweep/overtone mix. These are generated locally at runtime and are not recordings or imitations of real-world weapons.
- The new pass is presentation-only: server-side damage, range, cooldown and selection validation remain unchanged. There is no magazine/ammunition/reload economy in this phase.


### Weapon animation and impact FX pass
- Firing presentation now varies by archetype family: heavier arcade props use a short weighty kick, bow/lance archetypes use a draw-like pulse, staffs sweep, orbiting/disc props roll, and playful bubble/slime/duck props wobble.
- Confirmed beam endpoints now receive a weapon-aware impact burst. Pixel/glitch, bubble/slime, heavy spark, disc/orbit and playful confetti families use different particle silhouettes and inherit the weapon palette.
- These are client-side cosmetic effects only. They do not change server hit validation, cooldowns, range, damage, or match statistics.


## Android phone testing

The Android preset exports an **ARM64 debug APK**. GitHub Actions now checks the APK package ID, launch activity, ARM64 native library and debug signature, then uploads the APK together with its SHA-256 file and Android package report.

1. Open the latest successful **Godot CI - Windows EXE and Android APK** run under the repository's Actions tab.
2. Download the `OxenWar-Android-arm64-debug` artifact ZIP and extract it. It contains `OxenWar.apk`, `OxenWar.apk.sha256` and `android-badging.txt`.
3. Install `OxenWar.apk` on an ARM64 Android phone. Android may ask you to allow the file manager/browser used for that one installation to install apps. Do not disable device-wide security protections.
4. Launch in landscape. Check login form/keyboard, lobby layout, touch movement, right-side camera drag, jump, dash, sprint, slide, HUD buttons and scoreboard.
5. For an online LAN test, run the dedicated server on a PC connected to the same Wi-Fi and enter that PC's LAN IP in the game's server field. The server listens on UDP port 2456. Ticket-based multiplayer also requires the same server-only `OXENWAR_SERVER_SECRET` on the server and Supabase Edge Function; never put it in the client.

**Important:** the uploaded build is a debug build for device testing, not a Play Store release. CI now reuses a persistent cached debug signing key and assigns each APK a monotonically increasing Android version code based on the workflow run number. When moving from older builds made before the stable key was introduced, uninstall that older APK once if Android reports a signature conflict; consecutive builds from the stable-key series use the same signing certificate and can update in place. A successful APK export proves packaging/signing, not that the app has been exercised on a real phone. Touch responsiveness, frame rate, device thermals, login and live multiplayer still require physical-device testing.


## Collectibles and the 404 secret

Gold orbs are match collectibles that award score and XP; they are **not spendable coins or a currency wallet**. The HUD shows how many orbs were collected in the current session and whether the hidden 404 orb has been found. In online matches, these values are taken from the dedicated server snapshot; the secret is once per match. Offline progression keeps the local 404 discovery in the local save.
