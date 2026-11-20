# OxenWar overhaul — implementation and verification report

20 November 2026 · Godot 4.4.1 · Android build version 1.1.0 (code 2)

## Delivery status

**PARTIALLY IMPLEMENTED: the full AAA transformation remains incomplete.** This is a modified, runnable continuation of the supplied `Game-Phase4.zip`, not a replacement project or an image-only asset kit. It includes real source changes, imported geometry, editable Blender sources, platform builds and evidence. The current visuals are still stylized and visibly procedural. Professional character fidelity, complete authored animation and production online validation have not been achieved.

The supplied source was checkpointed as `8c4a8f7` before modifications. `SOURCE_COMMIT.txt` in the delivery identifies the final checkpoint; `CHANGES.patch` contains the changes. Historical Phase 2–4 reports remain in the source and describe earlier work, not current verification.

## IMPLEMENTED + VERIFIED

| System | Changes and evidence |
|---|---|
| Authenticated movement | The actual main-game authentication handler now keeps local movement prediction enabled. Server position reconciliation retains the player's newer look rotation. Tests exercise the real handler and correction path. |
| Input safety | Server rejects out-of-order positive input sequences and clears movement, sprint and queued abilities after 300 ms without accepted input. Menus/death send neutral controls. Shared default input bindings are idempotent and also initialize standalone player scenes. |
| Reload integration | A local reload request reaches a validated server RPC. The server checks identity, room, life state and equipped weapon, computes the same duration as the viewmodel, rejects firing during that interval, and replicates remaining time. Remote avatars lower the weapon and move the support hand. Switching and death/respawn clear transient state. All 27 registered archetypes are covered. This remains a recharge/presentation system; finite ammunition is not implemented. |
| Weapon geometry | Ranger Rifle, Heavy Sidearm and Longshot use actual CC0 Quaternius GLB bodies through the existing shared first-person/remote/arsenal builder. Their existing fictional energy attachments and gameplay values remain. Added real grip anchors, adjusted rifle attachment placement, preserved named animation nodes, generated UVs, and supplied editable `.blend` files. The other 24 existing procedural models remain available. |
| Preview/UI fixes | Fixed the lobby camera aiming before it entered the scene tree, which produced a blank preview. Missing cosmetic inventory now displays the actually equipped appearance with explicit read-only current values. Custom icon buttons no longer draw duplicate native captions, accept keyboard focus and display a focus outline. The touch round timer now reflows between or below the side panels; crosshairs hide in modal/dead/results states and results sit above the HUD. |
| Camera and scene lifecycle | Third-person collision compression hides the local avatar layer near the head; first-person camera-height logic no longer overwrites external-camera height. A beam allocated while no current scene exists is freed, fixing a resource leak exposed by the weapon integration test. |
| Audio controls | Independent persisted Master, SFX, Events, Music, UI, Weapons and Footsteps controls. Weapons and footsteps route through SFX to retain shared room reverb. Own and remote sounds use the correct buses. Stream/routing tests pass; this is not a claim of listening-based mix approval. |
| Android layout/input preparation | Scaled UI roots apply Android display safe-area insets, with a forced inset profile for regression testing. Added a hold-still gyroscope calibration control, finite bias loading and bias subtraction. Hardware behavior is not verified. |
| Materials and static maps | Reduced excessive global light/emission, increased surface roughness, and changed procedural grain to world-space projection to avoid stretching with box UVs. The seven existing layouts and collision design remain. Static opaque untextured world boxes can be grouped in MultiMeshes; imported/transparent meshes are excluded. |
| Geometry batching | Rendered engine readback verifies every batched transform against an original box; collision counts and repeat-call idempotence are checked on all seven maps. Jungle groups 95 boxes into 9 batches (86 fewer box submissions). Per-map batching savings are 0, 9, 4, 0, 19, 86, 13. These are structural draw reductions, not device FPS guarantees. |
| Regression quality | Retained the supplied tests; extended mixer expectations for the two new child buses and fixed test shutdown cleanup. New tests cover input safety, missing-inventory customization, integrated reload/UV/audio/safe-area behavior static batching and touch HUD clock collision/resize behavior. The final runner fails on engine errors as well as script failures. |

## Baseline and final checks

The original baseline ran **40 checks**, all passing their original exit/script-error gate. Reviewing their raw logs later showed input-map and fast-shutdown errors that this gate had overlooked. These were investigated and corrected; the final gate additionally counts `ERROR:` lines. Baseline logs are retained so the distinction is reviewable.

| Verification | Actual outcome | Limits |
|---|---|---|
| Final regression | **45/45**, exit 0, no GDScript errors, zero engine-error lines | Includes import, project structure, proxy, gameplay/UI/audio/rig/weapon suites and seven-map flow analysis. Warnings are retained in raw logs. |
| Two-client network | 18 shooter + 14 target assertions pass | Real localhost ENet transport and production room/input/combat code; identity redemption and persistence replaced by fixtures. Covers accepted/rejected fire, damage, elimination, respawn and disconnect cleanup. |
| Capacity/room isolation | 9 client processes; rooms of 8 and 1; 8 clients confirmed authoritative movement | Each client receives only its room's remote players. All clients receive their reload state; the eight-player room sees remote reloads and the isolated client does not. Not WAN or hosted authentication. |
| Reconnection | 9 assertions pass | Disconnect/new transport peer restores the original room and selected Longshot within the grace reservation. Fresh HTTPS ticket issuance is replaced by a fixture. |
| Rendered batching | Pass on all 7 maps using OpenGL | Headless dummy rendering cannot read back actual GPU instance transforms; this assertion is exercised separately with a display. |
| Screenshots | Actual Godot captures of menus, arsenal, weapons, HUD, settings, seven maps, results and staged remote avatars | Local fixture identities/data. Results and character lineups are staged presentation checks, not evidence of a won online match. Forced-touch captures are desktop simulations. |
| Windows export | Release EXE and PCK generated successfully | Keep both files together. The exported PCK was executed by Linux Godot as a smoke test. The Windows EXE was not executed. |
| Android export | ARM64 debug APK generated and signature verified | App ID `org.oxenwar.game`, minimum API 21, target/compile API 34, version 1.1.0/code 2. Not a production-signed store release. |
| Supabase health | `/auth/v1/health` returned HTTP 200 | `/rest/v1/` without a user JWT returned 401. Neither result verifies login, registration, RLS policies, friends or persisted stats. No hosted user records were created or changed. |

No screenshot was generated with image generation. Preview images are supplementary evidence; source geometry and project files are the deliverables.

## Actual architecture and integration

`main.tscn` loads `scripts/main.gd`, which assembles the menu, local player, map, HUD, effects and network node. `player.gd` handles local controls and viewmodel presentation. `oxenwar_server_player.gd` owns server-side movement/combat state. `oxenwar_network.gd` validates identity through the backend boundary, owns rooms and authoritative gameplay, and distributes snapshots. `oxenwar_remote_player.gd` applies appearance, interpolation and weapon presentation to remote avatars. `arcade_weapon_visuals.gd` is shared by equipped views and arsenal previews. `ArenaLayout` and `MapWorldBuilder` supply shared collision/world content. Supabase migrations/Edge Functions and hosting/proxy code remain in the project. Existing backend architecture was preserved; no migrations or live deployments were performed in this pass.

The reload change is integrated across local input, networking, server fire validation, snapshots and remote pose. The new models use that same equipment path; they are not decorative scene props.

## PARTIALLY IMPLEMENTED — character and art completeness

The archive contains **12 character GLBs**: ten Ghost armor/limb pieces and two gear meshes. It does not contain complete authored character packages for all the reference sheets. Existing procedural bodies, faces and limb animation remain playable. Ghost parts already use a runtime ten-bone rigid attachment rig; preserving and testing that rig is not equivalent to authoring a fully weighted humanoid character and animation library.

The default, Golden Pilot (`outfit_runner`), Ghost-Ops, Neon Riot, Iron Vanguard and Web Sentinel presentations can be rendered and exercised. They remain stylized procedural/mixed-asset characters. Exact troll facial shape, body proportions, clothing detail, deforming skin, authored animation clips and reference-faithful alternatives are outstanding. Sniper, Hazmat, Cyber, Brawler, Medic, Ninja, Demolitions, Officer and the four final-sheet archetypes were not reconstructed as complete production characters in this pass.

For a finished Ghost authored replacement, head, torso and hands are still needed as authored content. Suggested handoff names are `Ghost_Head.glb`, `Ghost_Torso.glb`, `Ghost_Hand_L.glb`, `Ghost_Hand_R.glb`; these are **not currently referenced missing imports**. The current game deliberately supplies procedural equivalents. Other character packages need complete meshes, skin weights, compatible skeleton/retarget data and clips. No missing file was invented or silently replaced with a generated picture.

All 27 weapons retain existing procedural switching, recoil, inspection and ADS/viewmodel behavior. Reload uses shared duration-based presentation, not 27 separately authored magazine/hand animation sets. First-person articulated hands and true sight-by-sight ADS alignment remain outstanding. No weapon damage/cooldown/range rebalance was made without supporting player data.

Maps retain obvious box-based arena geometry. Lighting, material readability and submission cost improved; there was no full environment rebuild, hand-authored PBR texture set, new LOD library or human competitive balance study. The interface has meaningful repaired behavior, but main-menu and HUD styles still differ; a complete visual redesign and accessibility/usability study remain open.

## IMPLEMENTED — NOT VERIFIED on target hardware

- Windows executable startup, graphics/audio/input behavior and installation on Windows. No Windows host or Wine was available here.
- Android APK installation/execution, physical touch ergonomics, gyroscope calibration accuracy, safe-area behavior on actual cutouts, thermal behavior, battery use and device FPS. `adb devices` listed no connected device; no emulator execution was performed.
- The calibration button and safe-area integration exist and their settings/layout contracts are tested. This does not establish Android hardware correctness.
- Audio routing, synthesis and resource references were tested. Render captures used the Dummy audio driver; no subjective listening approval is claimed.
- Performance captures used Mesa llvmpipe software rendering. Captured frame rates are not representative of gaming GPUs or phones. Counters vary with visibility, loading and capture timing; no 60/120 FPS target is certified.

## BLOCKED — live online verification

A usable test account (username/password or valid user session), a reachable configured game server and its correctly deployed server-side Supabase integration are required to verify the complete production chain. None was supplied as a working authenticated test setup. The embedded publishable key and a healthy auth service are insufficient. Server-only secrets are not present in the deliverable.

Consequently, real registration/login, HTTPS game-ticket issuance/redemption, authenticated matchmaking, real friend/presence interactions, production reconnect ticket renewal, durable statistics and server-authoritative reward writes are **not verified**. Local fixture tests do not prove these services. Latency/jitter/packet-loss behavior, malicious-client penetration testing, long-running soak tests and public matchmaking load remain outstanding.

## Asset inventory, accuracy and licensing

`ASSET_INVENTORY.json` and `.csv` list all 161 asset/source files, SHA-256 values, and GLB mesh/material/UV/triangle/skin/clip counts. `ASSET_STATUS.md` records every GLB individually. There are 28 runtime GLBs, including the three new weapon bodies. Counts describe stored GLB geometry, not the procedural geometry generated at runtime.

New external models are Quaternius CC0 assets, checked against the author/individual source pages. `assets/weapons/quaternius/CREDITS.md` records sources and modifications. Editable Blender files are in its `source_art` directory, excluded from runtime import. Materials are embedded PBR constants; the new bodies do not include authored roughness/metallic texture maps. UV coordinates were generated because the source models lacked them.

The supplied UI/audio attribution documents are retained. Rights/provenance for every pre-existing mesh/font were not independently established in this pass; the inventory says so. None of the three new bodies is claimed to be an exact reconstruction of a reference-sheet weapon. Reference similarity remains qualitative and incomplete, especially for characters. No FBX/OBJ/Unreal 5.7 validation was performed; this delivery targets the supplied Godot game.

## Remaining technical issues and review priorities

1. Full authored characters, first-person hands and a production animation library remain the largest content gap.
2. Live backend and hosted multiplayer require the authenticated/deployed setup described above.
3. Target-device testing and production signing are outstanding. A new standard debug signing key was generated for this APK; an older differently signed installation may require removal before installing it. The private key is not distributed.
4. A forced early exported-pack quit can leave an ObjectDB shutdown warning. The smoke test exits successfully without script errors; this warning is not presented as a clean long-session soak result.
5. Automated navigation/sightline/spawn analysis is not evidence that human matches are balanced or enjoyable. Matchmaking quality, progression feel and accessibility still need real users.
6. This is a substantive repair/integration/presentation pass, not a completed AAA release. Do not use this report as certification of content completeness, reference fidelity or hosted service availability.

## Reproducing the checks

Open the project with Godot 4.4.1 Standard. From the project directory:

```sh
python tools/qa/run_regression.py --godot /path/to/godot --output /path/to/logs
python tests/run_capacity_test.py /path/to/godot /path/to/capacity-logs
bash tests/run_reconnect_test.sh /path/to/godot /path/to/reconnect-logs
bash tests/run_online_test.sh /path/to/godot
```

Run the shell commands from the project directory. Rendering checks need a display/OpenGL: `godot --path . --script tests/test_static_world_batcher.gd`. Capture scripts under `tools/qa` use `OXENWAR_CAPTURE_DIR`. `capture_presentation.gd` uses local fixture profiles; it does not log into a real account. Export presets are included; configure local export templates, SDK/JDK and signing paths in the editor. Build runtime/toolchain downloads and private debug keys are not included in the ZIP.
