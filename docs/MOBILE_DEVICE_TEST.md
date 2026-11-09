# OxenWar Android device test checklist

## Build under test

- Workflow: **Godot CI - Windows EXE and Android APK**
- Artifact: `OxenWar-Android-arm64-debug`
- Package: `org.oxenwar.game`
- Architecture: `arm64-v8a`
- Build type: debug; not intended for public release

## Install

1. Download the artifact ZIP from the latest successful GitHub Actions run.
2. Extract the ZIP and verify `OxenWar.apk.sha256` against the APK with a SHA-256 utility when available.
3. Install the APK using Android's normal installation prompt. Grant only the one-time/source-specific install permission requested by Android.
4. If replacing a previous CI build, uninstall the old copy first because each workflow run creates a temporary debug signing key.

## Physical-device checks

- [ ] App starts and remains in landscape.
- [ ] Login/register fields are visible; the on-screen keyboard does not hide the active field or buttons.
- [ ] Lobby tabs, room input and mode selector fit inside the display.
- [ ] The left four-button movement pad responds and releases cleanly.
- [ ] Dragging on the open right side rotates the camera without moving the player.
- [ ] Jump, sprint, slide and dash respond; releasing a held touch button stops its action.
- [ ] HUD actions, weapon selector, emotes and scoreboard buttons do not overlap or block one another.
- [ ] No buttons are hidden by display cut-outs, rounded corners or Android navigation areas.
- [ ] Check frame pacing and heat after a 10-minute session; record any stutter or unexpected battery drain.

## Optional LAN multiplayer check

- Run the dedicated server on a PC on the same Wi-Fi.
- Enter the PC's LAN IPv4 address in the server field on the phone.
- Allow inbound UDP port 2456 through the PC firewall on the private LAN profile only.
- Ticket authentication requires `OXENWAR_SERVER_SECRET` to be configured identically in the server environment and Supabase Edge Function secrets. Never share or commit that secret.
- Confirm player join, movement replication, disconnect/reconnect and room join behavior. No public dedicated server is currently deployed.

## Test report

Record the Android model, Android version, screen resolution/refresh rate, workflow run URL, APK SHA-256, install result, approximate frame-rate feel, and each failed checklist item. Screenshots or a short screen recording of a visible defect are useful. Do not include account passwords or secrets in a report.
