# OxenWar repair and validation report

## Scope

This is a tested repair pass on the attached Godot 4.4.1 project. The project archive includes the game source, four original GLBs, two integrated environment GLBs, six restored audio assets with attribution, server code, Supabase functions and migrations, and CI workflows.

The entry point is `main.tscn`. Its controller builds the menu, HUD and arena. The player controller handles input and rendering. The network controller handles server-side input validation, room state and replication. The dedicated server builds each room from the shared arena layout. The Python Render entrypoint forwards WebSocket traffic to Godot. The Supabase functions handle account and game-ticket operations, while migrations describe social features, progression, and database permissions.

## Changes and verification

| Area | Status | Evidence |
|---|---|---|
| Event audio | IMPLEMENTED + VERIFIED | Restored all six missing OGGs via the project's existing download script. Each original SHA-256 matched and license files are included. The structural check now passes. Audio playback was not auditioned. |
| Touch input | IMPLEMENTED + VERIFIED | Action cleanup now skips bindings that have not been registered. The joystick test passes without the baseline missing-action diagnostic. |
| Friends and menu | IMPLEMENTED + VERIFIED | Search replies from superseded requests or obsolete menu renders are ignored and surrounding whitespace is trimmed. The overlay suite exercises an old reply arriving after the latest reply. |
| Menu presentation | IMPLEMENTED — NOT VERIFIED | Buttons use a 48 px minimum height. Old menu roots and preview models detach before deferred deletion. Layout was not tested on physical Android hardware. |
| Character consistency | PARTIALLY IMPLEMENTED | Server snapshots include the account accessory. Remote models apply the same cap/headphone selection as the local avatar and skip model rebuilds for repeated identities. Local Godot tests verified headphones and model reuse. A live authenticated two-client cosmetic match was not run. |
| 3D environment | IMPLEMENTED + VERIFIED | Redstone Canyon instantiates three background rocks from two original-kit GLBs. The dedicated room build skips them. Tests verify Godot instantiation, the absence of landmark collision and the four original GLB scenes loading with meshes. |
| Render service | IMPLEMENTED + VERIFIED | The endpoint returns HTTP 503 when the upstream connection fails and times out upstream connection attempts. The local proxy suite covers the unavailable server, health and the bidirectional tunnel. A real Godot WebSocket upgrade also passed. |
| Weapons and gameplay | PARTIALLY IMPLEMENTED | Existing test suite passes for 27 distinct procedural weapon models, character motion, locomotion, grenade physics, Bomb Rush, matchmaking, jungle layout and room isolation. Existing meshes and animation hooks were retained. No comprehensive balance or gameplay redesign was performed. |
| Exports | PARTIALLY IMPLEMENTED | Windows x86_64 release export produced an EXE and PCK. Windows execution was not tested. Android versioning tests passed. The Android export reported missing SDK/editor setup and debug signing, and no physical-device test was performed. |
| Hosted backend and broad overhaul | BLOCKED / NOT IMPLEMENTED | No live Supabase, hosted account flow, database migrations, production deployments or authenticated multiplayer matches were exercised. No comprehensive UI redesign, character/weapon geometry overhaul, device optimization or performance benchmark was completed. |

## Baseline versus final

The original archive failed structural validation because six event audio files were absent. Its joystick suite exited successfully but logged the missing `objective_interact` action. The Python Android versioning tests, proxy tunnel and original Godot suites exited successfully. The final suite passed all 16 scripted checks listed in `qa/final/status.txt`. The new and extended assertions cover imported models, room collision separation, latest search response, remote accessories and unavailable upstream handling. The client startup smoke run completed with an ObjectDB exit warning. Dedicated ENet and WebSocket startup passed, and the missing-secret server launch was rejected as expected.

## Run and export

Open `project.godot` in Godot 4.4.1 Standard and run `main.tscn`, or execute `godot --path .` from this directory. Run `godot --headless --editor --path . --import` before running the headless suites. See the README and `server/README.md` for server setup and the existing ticket configuration. Keep the required secret in the server environment.

Install the Godot 4.4.1 export templates and make the build directory. Run:

```sh
mkdir -p build
godot --headless --path . --export-release "Windows Desktop" build/OxenWar.exe
godot --headless --path . --export-debug "Android" build/OxenWar.apk
```

Keep the generated PCK alongside the Windows EXE. For Android, configure Java 17, the Android SDK and a debug keystore in Godot as described in the CI workflow and `MOBILE_DEVICE_TEST.md`.
