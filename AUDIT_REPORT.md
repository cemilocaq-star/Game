# OxenWar independent audit

20 November 2026. Baseline `515183d` is preserved by the local branch `checkpoint/pre-independent-audit`. This ZIP contains the complete tracked project at `31f9508`, targeting Godot 4.4.1 Standard.

The audit started with an independent baseline and compared the previous changes against the project source. It included focused review of gameplay, UI, asset integration, gameplay audio, maps, event scheduling, room lifecycle, persistence, tests and export configuration. Engine tests, renders and exports supplement manual source inspection. The work did not establish exhaustive correctness or complete the AAA art objective.

## Fixed

| Area | Root cause and correction | Evidence |
| --- | --- | --- |
| Room expiry | The final expired reconnect reservation removed the room without freeing its physics viewport. Now both are released, and departed users' profiles, join times and cooldown bookkeeping are pruned. | Room lifecycle test. |
| Client disconnect and room changes | Cleanup used the dedicated server's table. Reliable departures and snapshots could announce the same removal twice. Late snapshots could bring old avatars back. The client now clears its peer and input caches, emits each departure once and accepts snapshots only for the roster-announced room. | Lifecycle test and real local ENet combat, capacity and reconnect. WAN packet reordering was not separately simulated. |
| Joining rooms | Selecting the current room left and rejoined it. Private join decisions could outlive their source or target room. Current-room joins are idempotent. Private joins recheck peer, room and capacity after the friendship request. | Public rooms regression passed. Live friendship check remains unverified. |
| Respawn | Movement buffers, sprint and reload could carry into a new life or room. Initial room placement now uses the server's reset path, which clears temporary movement and reload state. Room switches also clear position and shot history. | Room lifecycle and real combat respawn checks. |
| Demolition | The regular clock could settle an armed round as a draw. It now waits for the fuse. The HUD shows the fuse, the detonation effect uses the actual map site, and the results screen uses the objective outcome. | Demolition and room lifecycle tests cover the timer and detonation. |
| FFA and results | A tie on both kills and score selected the first participant. Finish packets could also reuse stale stats. Both server and presentation recognize a draw, and the first round-end snapshot carries the full state. | Tied server result and snapshot-counter assertions. |
| Scoreboard and HUD | Equal names collided as dictionary keys. The table re-created all rows once per player update. Stats are now keyed by peer, departure removes the correct row, and updates trigger one refresh per frame. The touch event label is shorter and unassigned teams display FREE. | UI lifecycle regression and existing phone/HUD suites. |
| Cosmetics | Save sent disabled fallback fields and allowed overlapping writes from the same button. Its completion handler could access a deleted tab. It now writes editable fields, disables repeat submission, checks current account and tolerates a rebuilt tab. | Asynchronous test saves once, rebuilds the tab and preserves unavailable slots. |
| Third-person view | Local reload kept the normal aim pose. The close camera minimum could force the camera past thin cover. The local and remote avatars now share a blended reload pose, and the camera stops on the player side of the hit. | Existing grip, third-person, and reload checks plus game captures. No new authored clips. |
| Firing cost | Each shot loaded the settings file to read recoil scale. The setting is now loaded with input settings. | Viewmodel, weapon integration and server spread checks. |
| Auth session | Concurrent callers could independently rotate the same refresh token. A transient error cleared the session, and stale results could overwrite a newer session. Refresh requests now share a result, preserve the token on transient failure and protect newer sessions. | HTTP fixture exercises concurrency, transient failure, retry and stale completion. |
| Persistence | Round-end and departure could launch duplicate in-flight writes. The server now tracks a pending save before awaiting HTTP. | Persistence fixture counts a single write. The stats/mastery database operations are still separate. |
| Test reliability | Tests shared local profile files. An obsolete structural check matched a dead audio variable. Runner now isolates test data and checks the active spatial audio call. It also supports graphical imports. New lifecycle and asset tests are wired into CI. | Final strict suite and raw import logs. |

## Implemented and verified

- **49/49 final checks** passed with zero script or engine errors in the final run. The extracted source had completed its cold asset import before this run. Baseline was **45/45**.
- Binary asset validation checked all **28 GLBs** for framing, buffer/view bounds, image dependencies, vertex positions and attribute counts. Existing tests exercised Ghost-Ops joints, all **27** weapon types and collision/traversal analysis on all **seven** maps. Static asset checks do not certify reference accuracy.
- Two local ENet clients passed **18 shooter** and **14 target** assertions. Nine clients formed rooms of **8 and 1**, eight showed authoritative movement, and room-scoped reload replication passed. Reconnect passed **9** assertions. These tests use ticket and persistence fixtures. The separate localhost WebSocket proxy check passed within the strict suite.
- Actual software-rendered game captures covered menus, first- and third-person views, the arsenal, three imported weapons, all seven maps and the results screen. Draw-call and memory metrics were recorded with llvmpipe. No estimate of hardware FPS is inferred from them.
- **Windows release export, ARM64 Android debug export, APK signature verification and Linux Godot exported-PCK startup smoke test** each returned exit code zero. Exported binaries were generated for validation. This archive contains the complete editable project plus evidence and build configuration.

## Implemented but not verified

The refresh and private-room code was tested locally where possible. Live Supabase token rotation, private friendship lookup and persistent stats/rewards were not verified. Hosted CI execution, WAN impairment testing, long-running memory behavior and human gameplay balance remain unverified. Windows native execution and Android installation, touch, gyroscope, thermal behavior and device performance were not tested.

## Remaining issues and blocked work

- The supplied character art still uses procedural faces/body parts and rigid bone attachments. Complete skinned reference characters, first-person hands, authored animation clips, and production-quality texture/material authoring are missing. Three of 27 weapon types have authored replacement bodies. No new art packages were added in this audit.
- The maps retain their lightweight art and geometry. A human balance study and device profiling are still needed. Audio routing and synthesis tests passed. A listening-based mix review was not performed.
- Stats and weapon mastery are persisted in separate backend operations. Durable idempotency and atomic result persistence are still needed. The local in-flight guard prevents overlapping writes from the same server room member.
- A cold headless import produced 28 dummy-renderer thumbnail diagnostics. A cold OpenGL editor import completed and did not produce those thumbnail errors, but logged two environment Vulkan probe errors. The final cached import and runtime tests were clean. An intermediate UI fixture run exposed audio cleanup at shutdown, which was corrected. The forced fast-quit exported-pack smoke test can emit an ObjectDB shutdown warning. See the raw logs.
- Hosted verification needs a valid test account, target game server, deployed Supabase configuration and server-side credentials. No production changes were deployed.
- Native validation needs a Windows host and an Android device or emulator. Store signing and distribution need the release signing setup.

## Test results

| Gate | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| Original regression | 45 | 0 | 0 |
| Final strict regression | 49 | 0 | 0 |
| Separate local multiplayer scenarios | 3 | 0 | 0 |
| Export, signature and exported-pack smoke checks | 4 | 0 | 0 |

Unavailable hosted and native-device scenarios are listed separately above and are not counted as passing. Intermediate import and fixture diagnostics are preserved.

Open `project.godot` with Godot 4.4.1 Standard and let it import the assets. Run `python tools/qa/run_regression.py --godot /path/to/godot --output /path/to/results` in the project folder. For multiplayer see `tests/run_online_test.sh`, `tests/run_capacity_test.py` and `tests/run_reconnect_test.sh`. Build profiles, CI and server configs, Supabase functions/migrations, complete model and audio assets, tests and documentation are included. Caches, installed SDKs, temporary files and private keys are excluded.
