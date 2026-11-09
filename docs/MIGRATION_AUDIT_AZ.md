# OxenWar — texniki audit

Bu sənəd ilkin mühərrik köçürməsindən qalan qeydləri saxlayır. Cari onlayn hesab/dost/kosmetika sistemi və onun məhdudiyyətləri üçün əsas mənbə `README.md`-dir.

# PROJECT UNKNOWN — Unreal → Godot miqrasiya auditi

## Status

- **IMPLEMENTED + VERIFIED:** source archive extracted; source layout and project config inspected; original Unreal static checks run; safe original GLB assets copied; Godot starter project, Windows/Android export presets and local structural validation script added; no CI workflow included.
- **NOT VERIFIED:** Godot parser/editor import, playable runtime, Windows export, Android APK export, Android device input/gyro, multiplayer, network latency, performance and store signing. The AUTO graphics selection uses platform/CPU/GPU-name/display heuristics and runtime FPS sampling; it is not a full hardware benchmark. Real device FPS and thermal testing remain required. Godot is not installed in the current working container, so no Godot runtime test was possible.
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

- First-person CharacterBody3D movement, mouse look, jump buffering, coyote-time jumps, sprint, lowered slide stance, dash and stamina.
- Animated collectible visuals, timed 5-minute round, final-score screen and replay flow.
- Persistent XP/level progression, reward milestones, best-score save and one-time hidden 404 XP secret.
- Meme-inspired random events (BONK MODE, NPC MODE, DUCK.EXE) and toast feedback.
- Adjustable LOW/MEDIUM/HIGH/ULTRA neon shader presets plus AUTO quality heuristic using platform, CPU core count and screen resolution.
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


## Sonrakı inkişaf: Admin Power Panel və xəritə/event genişlənməsi

- Godot editorindən Play edilərkən `F8` ilə açılan Admin Power Panel əlavə edilib. Bu, yalnız editor feature flag aktiv olduqda görünür; export edilmiş oyunlarda qəsdən bağlıdır.
- Admin alətləri: uçuş rejimi (WASD + Space/Ctrl), God Mode state flag, Thor tipli çəkic kosmetikası, dekorativ ildırım, UFO və ördək troll effektləri, oyunçu bounce/reset, event-i əl ilə başlatmaq/dayandırmaq.
- Lokal arena variantları: Lost Mall, Neon City, Space Islands və Candy World. Bunlar hazırkı blokout arenasının əlavə platforma layout-larıdır, ayrıca tamamlanmış yüksək keyfiyyətli səhnələr kimi təqdim edilmir.
- Random event siyahısına METEOR_SHOWER (dekorativ), ICE_WORLD və DOUBLE_XP əlavə edilib.
- **Təhlükəsizlik sərhədi:** bu layihənin hazırkı versiyası offline/single-player prototipdir və server autentifikasiyası yoxdur. Buna görə Admin Panel export build-lərdə aktiv deyil. Real multiplayer admin əmrləri serverdə rol yoxlaması və server-authoritative icra tələb edir; gizli düymə və ya client config təhlükəsizlik sayılmır.
- **Verification:** GitHub faylları və struktur yoxlaması oxunub; Godot editor parse/runtime, real input, xəritə collision, multiplayer və EXE/APK testləri bu mühitdə aparılmayıb.


## FixerPly administrator identity

- Local prototype player display name is `FixerPly`; the Admin Power Panel is enabled only for the matching `ADMIN_PLAYER_NAME` check.
- F8 and an ADMIN HUD button open the panel.
- This local name check is not multiplayer authentication. Server-side immutable account identity and role authorization are required before enabling online admin commands.
