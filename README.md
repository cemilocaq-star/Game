# Project Unknown: Arcade Parkour (Godot migration)

This is the first Godot migration pass from the Unreal Engine 5.7 source package. It is a **playable-prototype codebase in progress**, not a verified release build.

## Current controls

- WASD / arrows: move
- Mouse: look
- Space: jump
- Shift: sprint
- Ctrl: slide
- Q: dash
- Escape: release/capture mouse
- Touchscreen: on-screen movement/action buttons and swipe look

Collect golden orbs for points. Random lighthearted events rotate during the round. The renderer is set to Compatibility for broad desktop/mobile support.

## Local opening and export

Install Godot 4.4.1 Standard (not .NET), open `project.godot`, then run `main.tscn`. The export presets are in `export_presets.cfg`: Windows x86_64 (`build/ProjectUnknown.exe`) and Android arm64 (`build/ProjectUnknown.apk`). Export locally from the Godot editor after installing the matching export templates; Android export also requires the Android SDK and JDK configured in Godot. No GitHub Actions workflow is included.

See `docs/MIGRATION_AUDIT_AZ.md` for exact status and known gaps.

## Important status honesty

The container used to prepare this migration did not have Godot installed. The structural validator can run locally, but it does not replace Godot parsing, runtime, export, device or multiplayer tests. Do not label the EXE/APK as built until they have actually been exported and checked.
