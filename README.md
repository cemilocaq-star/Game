# Project Unknown: Arcade Parkour (Godot migration)

This is the first Godot migration pass from the Unreal Engine 5.7 source package. It is a **playable-prototype codebase in progress**, not a verified release build.

## Current controls

- WASD / arrows: move
- Mouse: look
- Space: jump
- Shift: sprint
- Ctrl: slide (tap to start)
- Q: dash
- Escape: release/capture mouse
- Touchscreen: on-screen movement/action buttons and swipe look

Collect golden orbs for points. Orbs now rotate and bob, and respawn after collection. Slide uses a lowered stance; jump input buffering and a short coyote-time window make parkour controls more forgiving. A 5-minute round ends with a score screen and replay button. Random lighthearted events rotate during the round, including BONK MODE, NPC MODE and DUCK.EXE meme references. Collecting orbs grants persistent XP; levels unlock reward milestones, a 404 secret grants bonus XP, and your best score is saved. Graphics can be set to AUTO, LOW, MEDIUM, HIGH or ULTRA in-game. AUTO estimates a starting preset from platform, processor count, GPU adapter name and screen resolution, then adjusts quality using measured FPS. It is still a heuristic and needs real-device testing. Neon surface shaders and dynamic shadows scale with the selected preset. The renderer is set to Compatibility for broad desktop/mobile support.

## Local opening and export

Install Godot 4.4.1 Standard (not .NET), open `project.godot`, then run `main.tscn`. The export presets are in `export_presets.cfg`: Windows x86_64 (`build/ProjectUnknown.exe`) and Android arm64 (`build/ProjectUnknown.apk`). Export locally from the Godot editor after installing the matching export templates; Android export also requires the Android SDK and JDK configured in Godot. No GitHub Actions workflow is included.

See `docs/MIGRATION_AUDIT_AZ.md` for exact status and known gaps.

## Important status honesty

The container used to prepare this migration did not have Godot installed. The structural validator can run locally, but it does not replace Godot parsing, runtime, export, device or multiplayer tests. Do not label the EXE/APK as built until they have actually been exported and checked.


## Progression and graphics

Progression is saved locally in `user://progression.cfg`; graphics preference is saved in `user://game_settings.cfg`. XP is earned from collectibles. The XP requirement increases each level, with reward milestones at levels 3, 5, 10 and 20. A hidden 404 collectible grants a one-time XP bonus. The graphics selector supports AUTO/LOW/MEDIUM/HIGH/ULTRA. AUTO uses platform, CPU core count, GPU adapter name and display resolution as a starting estimate, then samples FPS every four seconds: it lowers quality after sustained low FPS and cautiously raises it after sustained high FPS. It is not a substitute for device testing and cannot guarantee a specific FPS. LOW disables the custom neon shader and shadows; higher presets progressively enable shader intensity and shadows.
