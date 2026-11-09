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

Install Godot 4.4.1 Standard (not .NET), open `project.godot`, then run `main.tscn`. The export presets are in `export_presets.cfg`: Windows x86_64 (`build/ProjectUnknown.exe`) and Android arm64 (`build/ProjectUnknown.apk`). Export locally from the Godot editor after installing the matching export templates; Android export also requires the Android SDK and JDK configured in Godot. GitHub Actions automatically validates the project and attempts Windows x86_64 EXE and Android arm64 debug APK exports on pushes and pull requests to `main`, and can also be started manually from the Actions tab. Successful builds are uploaded as workflow artifacts.

See `docs/MIGRATION_AUDIT_AZ.md` for exact status and known gaps.

## Important status honesty

The container used to prepare this migration did not have Godot installed. The structural validator can run locally, but it does not replace Godot parsing, runtime, export, device or multiplayer tests. Do not label the EXE/APK as built until they have actually been exported and checked.


## Progression and graphics

Progression is saved locally in `user://progression.cfg`; graphics preference is saved in `user://game_settings.cfg`. XP is earned from collectibles. The XP requirement increases each level, with reward milestones at levels 3, 5, 10 and 20. A hidden 404 collectible grants a one-time XP bonus. The graphics selector supports AUTO/LOW/MEDIUM/HIGH/ULTRA. AUTO uses platform, CPU core count, GPU adapter name and display resolution as a starting estimate, then samples FPS every four seconds: it lowers quality after sustained low FPS and cautiously raises it after sustained high FPS. It is not a substitute for device testing and cannot guarantee a specific FPS. LOW disables the custom neon shader and shadows; higher presets progressively enable shader intensity and shadows.


## Admin development tools and map variants

When the local player name is `FixerPly`, press **F8** (or use the ADMIN touch button) to open the Admin Power Panel. It includes fly mode (WASD + Space/Ctrl), a god-mode state flag for future damage systems, a first-person Thor-style hammer prop, a decorative lightning strike, UFO/duck meme effects, a bounce/reset utility, four local arena variants (Lost Mall, Neon City, Space Islands, Candy World), and manual event triggers. Random event rotation now also includes decorative Meteor Shower, Ice World and Double XP. The current FixerPly check is a local offline prototype identity gate, not secure online authentication. Proper multiplayer admin powers must be authorized and executed by the server.


### FixerPly admin identity

At startup, every player enters a display name. If the exact name `FixerPly` is entered, a masked admin-code field appears. The Admin Power Panel (F8 on desktop, ADMIN button on touch devices) is enabled only after the code is accepted. The local prototype compares a SHA-256 digest rather than storing the code as readable text. This remains a client-side offline gate, not secure authentication: anyone who can inspect or modify the game client can bypass it. An online release must validate credentials and admin roles on a trusted server.


### FixerPly admin code

At startup, players enter a display name. Entering `FixerPly` reveals a masked admin-code field; the admin panel is enabled only after the code is accepted. The local prototype compares a SHA-256 digest rather than storing the code as readable text. This is only a client-side offline gate, not secure authentication: anyone who can inspect or modify the game client can bypass it. An online release must validate credentials and admin roles on a trusted server.
