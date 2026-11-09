# PROJECT UNKNOWN — Unreal → Godot miqrasiya auditi

## Status

- **IMPLEMENTED + VERIFIED:** source archive extracted; source layout and project config inspected; original Unreal static checks run; safe original GLB assets copied; Godot starter project, Windows/Android export presets and local structural validation script added; no CI workflow included.
- **NOT VERIFIED:** Godot parser/editor import, playable runtime, Windows export, Android APK export, Android device input/gyro, multiplayer, network latency, performance and store signing. Godot is not installed in the current working container, so no Godot runtime test was possible.
- **BLOCKED / NOT INCLUDED:** Unreal-only C++/UMG/JNI code cannot be reused directly. Internet matchmaking, account backend and cross-platform online sessions were not complete in the original package and are not claimed as migrated. iOS output is not targeted in this first pass.

## Original package inventory

- 138 files in the extracted source folder; includes Unreal 5.7 `.uproject`, C++ classes, configuration/catalog JSON, Python/Blender tooling, documentation, tests and generated OBJ/MTL/GLB meshes.
- The `.uproject` pins EngineAssociation to 5.7 and references Unreal modules/plugins.
- `python Tests/run_static_checks.py`: **96/96 PASS** (source/static/asset checks only).
- `python Tests/verify_development_pass.py`: **49/49 PASS** (source/static/asset checks only).
- These checks do not compile Unreal C++, launch PIE, validate gameplay or produce an executable.

## Selected migration target

Godot 4.x with GDScript and GL Compatibility renderer. This is a practical cross-platform choice for a small arcade prototype because Godot supports Windows and Android exports. The project targets Godot 4.4.1. Windows and Android export presets are provided for local use in the Godot editor; no GitHub Actions workflow is included.

## Included safe carry-over assets

- `LostFoodCourt_Arena_Blockout.glb`
- `GoldenOrb_Collectible.glb`
- `DuckBeacon_Mascot.glb`
- `CosmicHalo_Cosmetic.glb`

These are original generated prototype meshes and remain blockout-quality, static assets. The new Godot demo also generates its collision arena from primitives so it does not depend on unverified GLB collision/import behavior.

## Excluded / not migrated in this pass

- Unreal C++ classes, UMG widgets, UPL/JNI glue and Unreal-specific import scripts.
- Combat-specific systems and their assets. This migration's playable direction is non-combat arcade parkour, collectibles, cosmetics and lighthearted world events.
- Uploaded helmet and character source assets with unresolved licensing/compatibility notes.
- Unreal-only animation and physics assets; no ready rigged character/skeleton was confirmed.

## Godot prototype features authored

- First-person CharacterBody3D movement, mouse look, jump, sprint, slide, dash and stamina.
- Touch buttons and swipe camera look path; Android gyroscope look path.
- Procedural low-poly arena, collectible score loop, collectible respawn and five lighthearted event states.
- Export presets for Windows x86_64 and Android arm64 APK.
- Local Windows and Android export presets are included; no `.exe` or `.apk` is bundled.

## Next required gate

1. Open `project.godot` in Godot 4.4.1 and fix any parser/import issues.
2. Install export templates and configure the Android SDK/JDK, then export Windows and Android builds locally.
3. Install the APK on a real Android device and verify touch hitboxes, gyro axes, frame rate and thermal behavior.
4. Add Godot multiplayer synchronization and test host/join on LAN; then separately plan an online session/backend if internet multiplayer is required.
5. Revisit visual polish, character model/animation, audio rights and save persistence.
