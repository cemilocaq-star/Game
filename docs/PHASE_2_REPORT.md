# OxenWar Phase 2

This archive continues the repaired project. Run it with Godot 4.4.1 Standard. The packaged Windows EXE requires its adjacent PCK. The Android artifact is a signed ARM64 debug APK for testing. Existing installations signed with a different key may reject it as an update.

## Implemented and verified locally

- The arsenal now presents a single, framed 3D preview built by the same code as the selected first-person model. Browse and rotate weapons before equipping them. The detail panel shows role, range and cycle time. The regression checks that selecting a different item replaces the preview.
- Equip and inspect tweens now own the weapon pose while active. Idle bob and recoil no longer overwrite the inspection height or depth, and switching no longer clears the current firing cooldown. These paths were parsed and exercised by the existing suite where applicable. No human weapon feel playtest was conducted.
- The shared outfit builder uses imported Pilot scarf geometry and Riot shield geometry in gameplay and customization. The existing articulated limbs, emote logic and swimming behavior remain in use. A test checks the imported meshes and the original outfit signature checks still pass.
- Every map now has an additional model landmark: a mall service crate, rooftop control box, floating rock, candy boundary marker, oasis palm, jungle lookout, and canyon cactus. The collision-only build skips these render assets. The existing three canyon landmarks also remain in use. Tests cover both client and collision-world creation.
- A remote K.O. transition briefly shows the avatar falling before it disappears. Respawn resets its pose. The transition is cosmetic and follows replicated death state.
- Godot 4.4.1 produced Windows x86-64 release and Android ARM64 debug artifacts. The APK was checked with aapt and apksigner. The archive carries both platform packages and their logs.

## Tests

The baseline from the previously repaired source passed all 16 scripted checks. The final run passed those 16 and the new presentation suite. Logs are in `docs/qa/phase2/`. The live handshake check launches an actual local Godot server. It does not exercise a hosted authentication session or an online match.

## Outstanding

The reviewed batch contains 99 static GLBs. Only selected compatible elements are wired into this project. The full troll meshes still need deformation-ready rigging and retargeting before they can replace the playable procedural avatars. The 27 existing arcade weapon silhouettes remain in use. No authoritative reload or ammo system, victory animation, full redesign of the remaining screens, map traversal rebalance, or performance benchmark was completed. No Supabase deployment, credential-backed auth, persisted match round trip, Windows runtime session, physical Android compatibility test or gyroscope calibration was performed.

Existing server and Supabase code and the previous repairs are included. This phase did not modify the persistence schema or service endpoints.
