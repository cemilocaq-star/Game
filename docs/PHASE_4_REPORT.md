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

## Automatic server discovery and join by room code

Request: no server address to type; joining a friend needs only the room code.

### IMPLEMENTED

- Supabase migration `20261115120000_oxenwar_server_directory.sql`: tables `oxenwar_servers` and `oxenwar_room_directory` (no direct client access) and two read functions, `oxenwar_find_server()` and `oxenwar_find_room_server(code)`, callable by signed-in players only.
- Edge Function action `sync_directory`: a dedicated server announces its address, player count and room codes (protected by `OXENWAR_SERVER_SECRET`, input validated).
- Dedicated server: registers itself every 25 seconds and within about 2 seconds of a room change. Public address from `OXENWAR_PUBLIC_HOST`, or detected on Render / Fly.io.
- Client: START and CREATE ROOM connect to the best online server; JOIN looks up the server that hosts the room code. A sleeping free-tier server is woken with one `/health` request. Nothing online leaves the player in the offline training arena with a clear toast.
- Menu: the server box moved behind **CUSTOM SERVER**; a status light shows `SERVER ONLINE • players` or `NO ONLINE SERVER`; CREATE ROOM and JOIN explain when no server is online.
- `tests/test_menu_ui.gd` updated for the new flow (fake backend with and without an online server).

### Limits (by design)

- A game server still has to run somewhere. The code finds a running server; it cannot create hosting. No public server is deployed yet.
- Rooms live in server memory, so a code stops working when the server restarts. Private rooms still require friendship with the room owner.

### BLOCKED until applied

- The migration and the Edge Function change are in the repository but **not applied** to the live Supabase project, and no dedicated server is deployed. Until both are done, the lobby shows `NO ONLINE SERVER`.

## Server netcode and weapon feel (research of ten shooters)

Request: study how ten FPS games run their servers (and their weapons, animation and maps) and improve OxenWar accordingly.

### Research summary (what the big shooters do, and what OxenWar did before)

| Technique | Seen in | OxenWar before | Now |
|---|---|---|---|
| Fixed server tick, clients decoupled from render rate | Valorant 128, CS2 sub-tick, OW2/R6 64, CoD/Halo 60, Fortnite 30, Apex 20 | 20 Hz snapshots, 20 Hz input | 30 Hz snapshots and input (same class as Fortnite/Apex-plus, cheap for 8-player rooms) |
| Client-side prediction + server reconciliation | Overwatch, Valorant, Source | Client predicted movement but was **hard-snapped to the 50-100 ms old server position (and server yaw) on every snapshot** | Input sequence numbers; client compares server position with its own position *at that input* and corrects only real disagreement (dead-zone, smooth nudge, snap above 3 m); mouse-look yaw is never overwritten |
| Snapshot interpolation (about 100 ms behind) | Source default, Overwatch | Remote players lerped toward the latest snapshot | Remote players are drawn 100 ms in the past between two real snapshots; extrapolation capped at 100 ms; teleports (respawn) do not glide |
| Lag compensation with a cap | Valve (rewind to the shooter's view), Overwatch (about 220 ms fairness clamp) | Hitscan tested enemies at their *current* position | Server keeps 1 s of position history and tests the shot against where each enemy was on the shooter's screen (half RTT + 100 ms), clamped to 220 ms; dead players no longer block shots |
| Lean snapshots | Source delta compression, Fortnite relevancy | Every snapshot carried about 40 fields per player | Fast fields every snapshot; names, colours, xp, mastery, collections only every 10th snapshot or when someone joins/leaves; client merges |
| Weapon feel: first shot accurate, bloom while firing, movement/ADS multipliers, per-weapon kick | CS2, Valorant, Apex, CoD | Perfectly accurate laser, visual-only recoil | Hybrid kick plus spread derived from fire rate and range; movement and aim multipliers; bloom recovers; kick partly returns; accessibility scale `gameplay/recoil_scale` (0 = no camera kick) |

### IMPLEMENTED

- `scripts/net_sync.gd` (interpolation buffer, position history, rewind clamp, ray-vs-capsule test, reconciliation), wired into `oxenwar_network.gd`, `oxenwar_remote_player.gd` and `main.gd`.
- Ping/pong RPC (`_server_ping` / `_client_pong`) measures round-trip time for the rewind amount.
- `scripts/weapon_feel.gd` wired into `player.gd` (`_fire_blaster`, `_process`).
- Tests `tests/test_net_sync.gd` and `tests/test_weapon_feel.gd` added to the CI workflow; `tests/validate_project.py` has new structural checks.

### VERIFIED

- Structural validation (`tests/validate_project.py`) passes locally.
- GitHub Actions (run 43709279602 on Phase4, commit 9e46f0d): project import with no script errors, the new net-sync and weapon-feel tests, and the full existing test suite all passed; Windows EXE and Android APK exports built. Two earlier runs failed on a parse error and a wrong test number; both were fixed.

### NOT VERIFIED

- No real multiplayer session was played: feel under real latency, jitter and packet loss, and the exact bandwidth saving of partial snapshots, are not measured.
- Weapon values (kick, spread) are first-pass numbers and need playtesting on PC and Android.

### NOT IMPLEMENTED (honest gaps)

- Full input replay (re-simulating unacknowledged inputs after a correction). The current reconciliation compares positions at the acknowledged input instead, which is simpler and safe but less exact under heavy correction.
- Spread is applied on the client; the server trusts the direction within a view-cone check. A server-side spread/anti-cheat model is future work.
- Map-flow changes (more routes, sightline mix, chokepoints, landmarks) and first-person animation upgrades (viewmodel sway/bob, ADS blend, additive reload): audited as recommendations only, because they cannot be verified without a running game.

### BLOCKED

- Downloading real-firearm 3D models, character GLB sets and authentic meme audio (items in the master directive): the build environment only reaches package registries and GitHub, not Sketchfab/CGTrader/sound libraries. These need files supplied by the owner or a network allowance.

## Randomized event system

### IMPLEMENTED AND VERIFIED (GitHub Actions run on this commit)

- The fixed 20 s clock is gone. Each room now waits a random gap (16-38 s, 12-28 s before the first event, +12 s calm after a disruptive event). When the gap ends an activation roll decides whether an event starts (75 %, 60 % of that for a lone player); a failed roll retries after 4-9 s and each failure adds 12 % so events never stall.
- The event is a weighted pick among events that are eligible right now: not the previous event, not on cooldown, enough players, allowed in this game mode and on this map, short enough to finish before the round ends, and no two Rare/Legendary/Secret events back to back. Only one event runs at a time.
- `tests/test_event_scheduling.gd` checks the configuration, every eligibility rule, the probability and gap ranges, and a simulation of 300 five-minute rounds (events per round, no overlaps or repeats, variety, legendary rarer than common, no long quiet periods). `tests/test_meme_events.gd` was updated for the new gap behaviour. Both passed in CI.

### Per-event configuration (from `scripts/meme_events.gd`)

Cooldown = time after the event starts before it can return in the same room (rarity cooldown + duration).

| Event | Weight (share) | Rarity | Duration | Cooldown | Min players | Disruptive | Blocked modes | Blocked maps |
|---|---|---|---|---|---|---|---|---|
| DUCK_PARADE | 20 (15%) | Common | 12 s | 57 s | 1 | no | - | - |
| PINK_SKY | 20 (15%) | Common | 12 s | 57 s | 1 | no | - | - |
| CONFETTI_STORM | 20 (15%) | Common | 12 s | 57 s | 1 | no | - | - |
| LOW_GRAVITY | 16 (12%) | Common | 12 s | 57 s | 1 | yes | demolition | - |
| GOLDEN_ORB_RUSH | 10 (7%) | Uncommon | 12 s | 87 s | 1 | no | - | - |
| BONK_MODE | 9 (7%) | Uncommon | 9 s | 84 s | 1 | yes | demolition | - |
| NPC_MODE | 8 (6%) | Uncommon | 9 s | 84 s | 1 | yes | - | - |
| ICE_WORLD | 7 (5%) | Uncommon | 10 s | 85 s | 1 | yes | demolition | Sunken Oasis |
| BIG_HEAD | 7 (5%) | Uncommon | 10 s | 85 s | 1 | no | - | - |
| DUCK_EXE | 4 (3%) | Rare | 10 s | 130 s | 1 | yes | - | - |
| METEOR_SHOWER | 4 (3%) | Rare | 10 s | 130 s | 1 | yes | - | Lost Mall |
| FREEZE_FRAME | 3 (2%) | Rare | 5 s | 125 s | 2 | yes | demolition | - |
| REVERSE_PANIC | 3 (2%) | Rare | 7 s | 127 s | 1 | yes | demolition | - |
| DOUBLE_XP | 2 (1%) | Legendary | 10 s | 190 s | 1 | no | - | - |
| SUNSHINE | 1 (1%) | Secret | 15 s | 255 s | 2 | yes | demolition, team_deathmatch, king_of_the_hill | - |

The map and mode blocks are design choices (for example no ice on the water map, no meteors inside the mall) and have not been playtested.

### Event presentation and audio status

- Visuals: each event already has procedural effects (`scripts/oxenwar_event_fx.gd`, `scripts/sunshine_fx.gd`) and the DuckBeacon GLB; these were not changed in this step and were not visually re-verified.
- Audio: the only integrated sounds are the CC0 Kenney cues and the qubodup loop listed in `docs/EVENT_AUDIO_ASSETS.md`, plus the original synthesized motif. **No authentic meme sounds are integrated and none were generated or labelled as memes.** The slots stay unassigned until licensed files are supplied.

### NOT VERIFIED

- Balance and feel in real matches; per-event audio timing; client reaction to the new gaps beyond the unchanged snapshot fields.

## Character visibility and feedback audio

- **Local character was invisible.** The local body is deliberately on a render layer the first-person camera skips, so players never saw their own model. IMPLEMENTED: a 2.6 s orbit intro when the match starts (front view swinging behind the character) and a `C` / on-screen `VIEW` third-person camera with wall pull-in, the weapon aimed from the head toward the crosshair point, firing blocked only during the intro. `tests/test_third_person_view.gd` passed in CI. NOT VERIFIED: how it looks and feels in play on PC/phone; the first-person weapon is hidden in third person (no held weapon on the local body yet).
- **Feedback audio.** See `docs/SFX_RESEARCH.md`. IMPLEMENTED: original synthesized cues, director and menu sounds. NOT VERIFIED: listening balance. Follow-up: layered weapon audio, wall occlusion and nine recorded CC0 sounds are IMPLEMENTED and unit-tested (see `docs/SFX_RESEARCH.md`); recorded gunshots are BLOCKED (no reachable redistributable gun recordings); meme sounds remain unassigned.

## Ghost rig animation tests

`tests/test_ghost_rig_animation.gd` drives the Ghost-Ops costume (ten rigid limb shells on a Skeleton3D) through idle, walk, run, slide, airborne, the four emotes and defeat, plus state transitions, a weapon hold and random abuse.

- **IMPLEMENTED AND VERIFIED (headless, local Godot 4.4.1 and CI):** every bone follows its locomotion pivot; joints stay closed (no gap at elbow or knee); limbs never stretch (< 0.2 mm); the knee only bends backwards and the elbow never bends backwards; shoulders stay in range; no bone moves more than 0.25 rad in a frame (0.35 across state changes); arm shells stay outside the torso; foot shells do not sink more than 10 cm; run cycle is left/right symmetric, in opposition and repeats after one stride period; the glove reaches a weapon hold target within 2 cm; poses stay finite and bounded under 600 random inputs.
- **Bug found and fixed by these tests:** the robot, wave, griddy and goofy emotes used inverted arm angles. In this rig a positive X rotation swings a hanging arm forward, but the emotes drove the arms backwards: in the robot emote both hands ended 47-60 cm *behind* the shoulders, the victory wave raised the hand 59 cm behind the body, and robot/wave bent the elbow backwards (down to -1.03 rad, outside `ELBOW_LIMITS`). The signs are corrected; the old wave test (`rotation.x < -0.05`) had encoded the wrong direction and now expects `> 0.05`. NOT VERIFIED visually: only geometry was measured, nobody has watched the emotes on a screen.
- **NOT TESTABLE on the Ghost shells (no such part exists):** head shell look-at/nod/turn limits, torso shell lean/twist/breathing, hips/pelvis motion and pelvis-driven foot IK, hand/finger shells and grip closing, spine/neck bones, skin-weight deformation (the shells are rigid, joints are checked as gaps instead). The head (`HeadPivot`) and torso capsule are procedural meshes that are animated, but they are not Ghost assets. The test prints these notes and updates them itself when such bones are added.
- **Observation, not changed:** the foot shells dip up to about 7 cm below the ground line while running (toe pitch with no ground IK); at rest they are 2 cm below it.

## Stage 6: audio (sound paths, footsteps, buses, room reverb)

Code: `scripts/sound_paths.gd`, `world_audio.gd`, `footstep_audio.gd`, `audio_buses.gd`, `room_acoustics.gd`, `room_acoustics_driver.gd`. Tests: `test_sound_paths.gd`, `test_footsteps.gd`, `test_room_acoustics.gd`.

- **Sound paths.** A sound with a blocked straight line looks for a one-bend way around the obstacle (7 sideways offsets, both sides). If there is one, the sound is placed at an apparent position along the bend direction at the full path length, so Godot's own distance attenuation and panning carry the detour; it is also low-passed (9 kHz to 1.8 kHz) and quieted (-1.5 to -6.5 dB) by how sharp the bend is. With no way around, or behind more than one wall, it falls back to the existing wall muffling profile. Used for other players' gunfire, grenade explosions (new synthesized "explosion" sound) and other players' footsteps.
- **Footsteps.** One shared module (`footstep_audio.gd`) for the local player and for other players, who now have footsteps too (one every 1.55 m walking, 2.05 m sprinting; none while sliding, airborne or defeated). Every map's floor was named `ArenaFloor`, so all seven maps played "stone"; `tag_tree` now gives every solid body the map's ground (Lost Mall stone, Neon City and Space Islands metal, Candy World ice, Sunken Oasis and Redstone Canyon dirt, Jungle grass) and wooden things (bridge, treehouse, rope, plank, dock, boardwalk) by name. An existing `surface_type` meta or `surface_*` group is never overwritten.
- **Buses.** SFX (positional world sounds, carries the room reverb), Events, Music, UI, all sending to Master so the master volume still controls everything.
- **Room acoustics.** 13 rays (8 sideways, 1 up, 4 diagonal) every 0.2 s from the listening camera measure how enclosed it is and how far the walls are; the SFX reverb (wet 0.02 to 0.34, room size, damping) eases toward the result at 2.2/s so it never jumps.

### IMPLEMENTED AND VERIFIED (headless Godot 4.4.1, local run of every CI test script)
- Sound path resolution on synthetic geometry and on real physics bodies; `WorldAudio` bending, direct and out-of-range cases; the grenade explosion plays through it.
- Footstep classification, per-map ground, wood by name, tagging without overwriting, every solid in all seven generated maps gets a surface, surface detection through real physics (meta, group, name, excluded body, nothing underfoot), per-surface streams, remote players' footsteps (count per distance, silent when still, sliding, airborne or defeated).
- Bus layout (idempotent, exactly one reverb), routing of world sounds / menu sounds / feedback ticks, enclosure ordering (open < courtyard < roofed room), reverb ordering and caps, easing without overshoot, the live driver in a real closed room and back in the open. A deliberate break of the reverb formula made the test fail.

### IMPLEMENTED BUT NOT VERIFIED
- How it sounds. Headless Godot runs a dummy audio driver, so the actual filter, panning, reverb tail and loudness balance have not been heard by anyone. The constants (cutoffs, dB offsets, reverb caps, volumes) are reasoned values and need listening on a device.
- Event cues, music and emote beat now play on the Events/Music buses; only the bus name is tested, not the mix.
- Online play: remote footsteps and gunfire are driven by snapshot positions and the fire effect, and have not been exercised in a live two-client session.

### NOT IMPLEMENTED
- Sound propagation through more than one bend (a corridor with two turns falls back to muffling).
- Footsteps for swimming / water surfaces, and materials inside buildings that differ from the map ground (only wood by name).
- Per-bus volume sliders in the settings (only the master volume exists).

### BLOCKED
- Nothing in this stage is blocked by missing assets; all sounds are synthesized.

## Exports and checks

The ZIP contains Windows x86-64 EXE/PCK and a signed ARM64 Android debug APK, plus build logs and APK signature/package checks. See `docs/qa/phase4`. To repeat the new regression after importing the project, run `godot --headless --path . --script tests/test_meme_events.gd`.
