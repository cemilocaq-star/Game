# OxenWar Phase 4

Built on the Phase 3 source. Godot 4.4.1 Standard opens the project. Keep the Windows EXE and PCK together. The Android APK is intended for ARM64 debug testing.

## Implemented and verified

- Replaced uniform online event selection with a weighted configuration. Five rarity tiers, per-event durations, an exclusive active slot, a 20-second cooldown, no immediate repeats, and mode/alive-player filters are integrated into the existing server room loop.
- The Sunshine regression creates a real room physics world and checks the three-second no-movement period, bounded tracking, one authoritative death, replication payload, no repeated death after respawn, and target-loss cancellation. A separate client-side assertion checks countdown and impact presentation.
- The existing Phase 3 suites remain in use. See the included baseline and final status files and logs for exact outcomes.

## Implemented but not fully verified

| Event or feature | Implementation and remaining verification |
|---|---|
| LeBron James: You Are My Sunshine | Secret-tier FFA event for rooms with at least two living players. An original basketball troll parody, animated storm meshes, lightning flashes, positional synthesized thunder, countdown, collision-checked flight, impact message and existing K.O./respawn path are wired into online room snapshots. Flight can time out when geometry blocks pursuit. Multi-client gameplay, visual rendering, and audio timing were not exercised through hosted play. |
| The Big Head Incident | Enlarges avatar heads with unchanged collision and restores them at event end. No authenticated multi-client test. |
| Reverse Controls Panic | Reverses movement input on the server and mirrors the effect in local movement. Excluded from Demolition. In-match control feel was not playtested. |
| Duck Parade | Existing mascot and effects, now weighted. |
| Duck.EXE | Existing variant and effects, now weighted. The requested Duck Apocalypse expansion remains open. |
| Pink Sky | Existing cosmetic event, now weighted. |
| Confetti Storm | Existing cosmetic event, now weighted. |
| Low Gravity | Existing authoritative movement event, now weighted. The requested Gravity Has Left concept uses this existing implementation. |
| Golden Orb Rush | Existing authoritative reward event, now weighted. |
| Double XP | Existing authoritative reward event, now weighted as Legendary. |
| Bonk Mode | Existing authoritative speed event, now weighted. |
| NPC Mode | Existing movement effect, now weighted. The requested NPC Army content remains open. |
| Ice World | Existing slippery movement event, now weighted. The requested Banana Incident content remains open. |
| Freeze Frame | Existing freeze event, now weighted and shorter. |
| Meteor Shower | Existing cosmetic event, now weighted. The requested Meteor Delivery Service gameplay remains open. |
| Aim presentation | Desktop right-click camera zoom honors death, menus and current weapon tweens. No per-weapon sight alignment or Android aim control. |

## Not implemented

- Emotional Damage, Final Boss Music, Instant Regret, Fitness Influencer, Windows Error, Ceiling Fan Incident, NPC Has Had Enough, Orchestra of Chaos, Potato King, Philosophical Chicken, Server Is Confused, Floor Is Lava, Personal Fan Club, Granny, Wrong Game Mode, and the ten additional original events.
- Event combinations and discovery log. The compatibility policy currently permits one active event and filters selected modes.
- Physical ragdoll, fully authored character skinning, reload/ammo behavior, comprehensive UI redesign and competitive arena performance/balance testing.
- Sunshine uses original synthesized thunder and the existing attributed event soundtrack. No licensed copy of the named song was supplied. Separate event-volume settings and cross-client audio alignment remain open.

## Blocked

- Authenticated live matches and Supabase persistence require test accounts and a test deployment. Local WebSocket and ENet smoke tests do not exercise those flows.
- Native Windows execution and physical Android testing require corresponding runtime access or hardware. Screenshots were not captured in this headless run.

## Main menu redesign and lobby button fixes

Reason: the START and CREATE ROOM buttons did nothing, and the menu did not feel like a shooter. Root cause: the game ships without a default server address, and the three lobby buttons were disabled until a valid address was typed. The only explanation was a small line of text.

### IMPLEMENTED

- **Buttons never dead.** START, CREATE ROOM and JOIN are always enabled. START with an empty server address opens the offline training arena (`launch_action: "practice"`) and shows a toast. CREATE ROOM and JOIN with no address show a banner and focus the address field. A malformed address shows an error banner. A bad room code shows an error banner.
- **Server address remembered.** The last valid address is saved in `user://game_settings.cfg` (`network/server_host`) and restored on the next start. The typed address and room code now survive tab switches and language changes (they used to reset).
- **FPS-style lobby.** Top navigation bar with player chip, mode cards on the left (Free For All, Team Deathmatch, King of the Hill, Bomb Rush) with a description each, the player's own 3D character in the middle, map tiles with a colour per map, a server status light and one large angled START button on the right. Animated dark backdrop with drifting light bars. Angled buttons, sharp panels, selected-card accent bars. The pattern follows what Valorant, CS2, Apex Legends and Call of Duty lobbies share; no assets or layouts were copied.
- **Career tab.** Statistics are shown as a grid of large value tiles instead of plain rows. Friends list shows an online/offline status light.
- **Pause menu** uses the same style (RESUME primary, LEAVE MATCH danger). Button texts and signals are unchanged.
- **Connection hint.** If the server connection fails after launch, a toast explains how to change the server (before, the player stood frozen with no hint).
- New localized strings in Azerbaijani, English, Turkish and Russian (`EXTRA` table in `oxenwar_i18n.gd`).
- New files: `scripts/fps_ui.gd`, `tests/test_menu_ui.gd` (added to the CI workflow).

### UI errors found and fixed

| Error | Fix |
|---|---|
| Lobby buttons disabled with no clear reason | Always enabled; explain the missing step |
| Typed server address and room code lost on tab or language change | Kept in menu state and saved |
| Short labels with word wrap collapse to a sliver inside rows (XP, friend rows) | Only long text wraps |
| Sign-out button hidden at the bottom of the play tab | Moved to the top bar |
| Frozen player after a failed connection with no explanation | Toast with the next step |
| Pause menu looked unrelated to the menu | Shared style |

### VERIFIED

- `python3 tests/validate_project.py` passes (56 required files, plus new checks that the lobby buttons are never disabled again).
- GitHub Actions run 43649089076 on branch `Phase4` (commit d0c58cb, Godot 4.4.1): project import with no GDScript parse errors, the new `tests/test_menu_ui.gd` (button behaviour, offline fallback, server hints, tab persistence, translations), `tests/test_ui_overlays.gd` (pause menu), `tests/test_mobile_joystick.gd`, the other existing suites, the Windows x86-64 export and the Android arm64 debug APK export all passed.

### NOT VERIFIED

- Nothing was looked at on screen. The angled button shape (`StyleBoxFlat.skew`), the 3D hero stage, the layout on a real phone and the backdrop animation need a visual check on a device.
- Online matches against a real server were not exercised.

### BLOCKED

- A default public server address. The Render service name suggests `oxenwar-game-server`, but the deployed URL is not confirmed, so none is hard-coded. Set `oxenwar/server_host` in `project.godot` or the `OXENWAR_SERVER_HOST` environment variable to ship one.

## Exports and checks

The ZIP contains Windows x86-64 EXE/PCK and a signed ARM64 Android debug APK, plus build logs and APK signature/package checks. See `docs/qa/phase4`. To repeat the new regression after importing the project, run `godot --headless --path . --script tests/test_meme_events.gd`.
