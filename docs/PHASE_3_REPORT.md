# OxenWar Phase 3

Built from the Phase 2 source. The project, both build targets, and QA logs are included. Open the project in Godot 4.4.1 Standard. Keep OxenWar.pck beside OxenWar.exe. The Android APK is signed for debug testing with the same workspace debug key as Phase 2.

| Area | Status | Evidence and limits |
|---|---|---|
| Skeleton-driven Ghost-Ops clothing | IMPLEMENTED + VERIFIED | Ten imported rigid limb sections bind to a Skeleton3D with parented bones driven by the existing locomotion rig. The shared build path applies in gameplay, on remote avatars and in customization. The regression verifies the bone hierarchy and that a mesh attachment follows its driving pose. This is a partial character replacement. The torso, face, hands and other outfits still use the existing procedural meshes. |
| Third-person weapon presentation | IMPLEMENTED + VERIFIED | All 27 replicated weapon IDs build the same model used by first person and the arsenal. Tests exercise model changes, reuse on unchanged snapshots, fire kick, death hiding and respawn reset. Remote fire reuses the weapon-specific synthesized sound bank. Timing over a live authenticated session and hand fit from different camera angles remain unverified. |
| Respawn and match outcomes | PARTIALLY IMPLEMENTED | The first-person model clears tweens and recoil across death and respawn. Replicated match outcomes drive a reused victory wave and a lowered-head defeat pose. FFA winning results now declare a win rather than leaving the winner at the default draw. Death/respawn has direct regression coverage. End-of-match pose playback and hosted stat persistence were not exercised. |
| Combat | IMPLEMENTED + VERIFIED | Authoritative shot facing now follows the same negative-Z basis used by the client. The regression compares five yaw headings. Slide fire originates lower than standing fire. Both paths still use server-side hit and damage decisions. Human balance and latency testing remain open. |
| UI and maps | PARTIALLY IMPLEMENTED | Shared theme defaults cover the menu, pause screen, HUD and its panels. Match results have a scrolling layout and reveal transition. All seven arenas get distinct sky palettes. Geometry, cover, spawn and sightline balance were not changed without playtesting. Visual UI and performance verification remain open. |
| Windows and Android | IMPLEMENTED + VERIFIED | Godot exported the Windows x86-64 release and the ARM64 Android debug build. APK package metadata and signature were checked. Native Windows and physical Android execution, device touch, gyroscope, thermals, and frame pacing remain unverified. |
| Hosted multiplayer and Supabase | BLOCKED | The local ENet smoke test and real Godot WebSocket proxy handshake passed. No authorized live test accounts or isolated test backend were available. Registration, authenticated matches, friends/presence, reconnect across real clients and persistent rewards were not exercised. |
| Full character and weapon completion | PARTIALLY IMPLEMENTED | Production deforming skins for all character assets, authored full-body clips, an authoritative reload/ammo system and ADS remain open. Existing firing, inspection and switching were preserved. |
| Screenshots | BLOCKED | No working graphical display backend was available for this run. The attempted X server could not establish a writable display lock in this runtime. No synthetic screenshots are supplied. |

## Test results

The Phase 2 baseline passed 17 checks. Phase 3 passed all 18 checks including the new skeletal, weapon and aiming regression. The original suites still cover joystick transitions, weapon visuals, character motion, gameplay physics, matchmaking, room isolation, UI and map builds. A clean resource import can emit dummy-renderer texture preview warnings during headless GLB import. The scene instantiation tests pass.

Run `godot --headless --editor --path . --import` and `godot --headless --path . --script tests/test_phase3_presentation.gd` from the project folder. See `docs/qa/phase3/` for the baseline and final logs and the Ghost-Ops conversion script.
