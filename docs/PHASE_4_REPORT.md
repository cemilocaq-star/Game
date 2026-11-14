# OxenWar Phase 4

Built on the Phase 3 source. Godot 4.4.1 Standard opens the project. Keep the Windows EXE and PCK together. The Android APK is intended for ARM64 debug testing.

## Implemented and verified

- Replaced uniform online event selection with a weighted configuration. Five rarity tiers, per-event durations, an exclusive active slot, a 20-second cooldown, no immediate repeats, and mode/alive-player filters are integrated into the existing server room loop.
- The Sunshine regression creates a real room physics world and checks the three-second no-movement period, bounded tracking, one authoritative death, replication payload, no repeated death after respawn, and target-loss cancellation. A separate client-side assertion checks countdown and impact presentation.
- The existing Phase 3 suites remain in use. See the included baseline and final status files and logs for exact outcomes.

## Implemented but not fully verified

| Event or feature | Implementation and remaining verification |
|---|---|
| LeBron James: You Are My Sunshine | Secret-tier FFA event for rooms with at least two living players. An original basketball troll parody, animated storm meshes, lightning flashes, positional synthesized thunder, countdown, collision-checked flight, impact message and existing K.O./respawn path are wired into online room snapshots. Flight can time out when geometry blocks pursuit. Multi-client gameplay, visual rendering, and audio timing were not exercised through hosted play. |
| The Big Head Incident | Enlarges avatar heads with unchanged collision and restores them at event end. No authenticated multi-client test. |
| Reverse Controls Panic | Reverses movement input on the server and mirrors the effect in local movement. Excluded from Demolition. In-match control feel was not playtested. |
| Duck Parade | Existing mascot and effects, now weighted. |
| Duck.EXE | Existing variant and effects, now weighted. The requested Duck Apocalypse expansion remains open. |
| Pink Sky | Existing cosmetic event, now weighted. |
| Confetti Storm | Existing cosmetic event, now weighted. |
| Low Gravity | Existing authoritative movement event, now weighted. The requested Gravity Has Left concept uses this existing implementation. |
| Golden Orb Rush | Existing authoritative reward event, now weighted. |
| Double XP | Existing authoritative reward event, now weighted as Legendary. |
| Bonk Mode | Existing authoritative speed event, now weighted. |
| NPC Mode | Existing movement effect, now weighted. The requested NPC Army content remains open. |
| Ice World | Existing slippery movement event, now weighted. The requested Banana Incident content remains open. |
| Freeze Frame | Existing freeze event, now weighted and shorter. |
| Meteor Shower | Existing cosmetic event, now weighted. The requested Meteor Delivery Service gameplay remains open. |
| Aim presentation | Desktop right-click camera zoom honors death, menus and current weapon tweens. No per-weapon sight alignment or Android aim control. |

## Not implemented

- Emotional Damage, Final Boss Music, Instant Regret, Fitness Influencer, Windows Error, Ceiling Fan Incident, NPC Has Had Enough, Orchestra of Chaos, Potato King, Philosophical Chicken, Server Is Confused, Floor Is Lava, Personal Fan Club, Granny, Wrong Game Mode, and the ten additional original events.
- Event combinations and discovery log. The compatibility policy currently permits one active event and filters selected modes.
- Physical ragdoll, fully authored character skinning, reload/ammo behavior, comprehensive UI redesign and competitive arena performance/balance testing.
- Sunshine uses original synthesized thunder and the existing attributed event soundtrack. No licensed copy of the named song was supplied. Separate event-volume settings and cross-client audio alignment remain open.

## Blocked

- Authenticated live matches and Supabase persistence require test accounts and a test deployment. Local WebSocket and ENet smoke tests do not exercise those flows.
- Native Windows execution and physical Android testing require corresponding runtime access or hardware. Screenshots were not captured in this headless run.

## Exports and checks

The ZIP contains Windows x86-64 EXE/PCK and a signed ARM64 Android debug APK, plus build logs and APK signature/package checks. See `docs/qa/phase4`. To repeat the new regression after importing the project, run `godot --headless --path . --script tests/test_meme_events.gd`.
