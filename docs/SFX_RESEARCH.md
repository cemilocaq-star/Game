# Shooter sound-effect research and what OxenWar did with it

Honest scope: three sources were read in full (PC Gamer on Overwatch audio, Splice on weapon-sound layering, a CS2 sound-design article). Several more pages came up in searches (Call of Duty "most-heard sound", DICE Battlefield audio slides, Valorant/Apex footstep and settings guides, hit-marker articles) but only their titles were seen, so no claims below rest on them. Game sound files are copyrighted and were **not** copied or downloaded; everything added is synthesized from scratch in `scripts/sfx_bank.gd`.

| Game | Documented practice (source read) | Adapted to OxenWar | Status |
|---|---|---|---|
| Overwatch | Mix by importance (who looks at you, shoots you, how far), not just loudest-wins; sound paths give muffling around corners; friend/foe readable cues; filter chatter so only informative sounds play | Priority on the combat channel (kill > damage > hit); a hit tick never cuts a kill ding; `scripts/sound_occlusion.gd` muffles and softens other players' gunfire behind walls (straight-ray approximation, up to 3 surfaces) | Priority and ray occlusion IMPLEMENTED; true sound pathing around corners NOT IMPLEMENTED |
| Counter-Strike 2 | Footsteps tell direction, speed and distance; crouching/walking is quieter; gunfire identifies position and weapon; grenade/utility sounds signal pushes | OxenWar already has surface footsteps (grass/metal/wood/ice/stone) and 3D remote weapon audio | Existing, not changed |
| Generic layered weapon design (Splice) | Layers: mechanics, low end, close detail, far detail, tail; simplified non-player fire; vary pitch/volume and layers to avoid repetition | `scripts/weapon_audio.gd`: crack + body + sub thump + mechanical clack + tail, 3 variants per weapon with millisecond layer offsets, simplified "far" version for other players | IMPLEMENTED and unit-tested |
| Shooters in general | Short bright hit tick, distinct kill confirmation, low-health heartbeat, countdown ticks, accelerating bomb beeps | `hit`, `kill`, `damage`, `heartbeat`, `beep`, `tick` cues and `ui_hover`/`ui_click` for the menu | IMPLEMENTED and unit-tested |

## What was added

- `scripts/sfx_bank.gd`: eight original cues (tone bursts with decay, noise and harmonics), deterministic and cached.
- `scripts/sfx_director.gd`: plays hit/kill/damage from the local player's combat feedback, a heartbeat below 30 % health that speeds up as health falls, bomb beeps that accelerate as the fuse burns (and stop if match state stops arriving), and a tick for each of the last ten seconds.
- Menu hover/click sounds on every FPS-style button, nav tab and card (`FPS_UI.attach_sounds`).

## Not verified / limits

- Tests check the generated audio (format, length, peak, determinism) and the director's timing logic. **Nobody has listened to it**: loudness balance against gunfire and music, and whether the cues sound good, need ears on PC and phone.
- These are plain synthesized cues, not recordings; they will sound simpler than a commercial game. Licensed recordings (for example CC0 packs) can replace the generated streams later by changing `SFX_BANK.stream`.
- No meme sounds were added or generated.

## Layered weapons, occlusion and recorded sounds (follow-up)

- **Weapon layers**: your own shots use crack + body + sub + clack + tail and pick one of three variants each shot (the three are prewarmed when you equip a weapon so there is no hitch). Other players are heard in the simplified "far" layering with a longer, darker tail.
- **Occlusion**: each remote shot casts a ray from your head to the shooter; every separate solid surface (up to three) lowers the low-pass cutoff (2400 / 1200 / 700 Hz) and the volume (-4 / -8 / -12 dB). Only weapon fire is occluded so far (not grenades, footsteps or events).
- **Recorded licensed sounds**: nine Kenney CC0 1.0 recordings were added under `assets/audio/sfx/` (hit-light, hit-medium, hit-heavy, land, menu-move, menu-confirm, menu-back, respawn, throw). Source: the pinned `blancmathis/Super_Bash_Folds` open-audio folder, whose provenance file credits Kenney Impact Sounds and Interface Sounds (CC0); file hashes were checked against its `SHA256SUMS` and are pinned in `tools/fetch_open_audio_assets.py`. They are used as impact layers under hit/damage/kill cues, for landing, grenade throw, respawn and menu clicks.
- **BLOCKED - recorded gunshots**: no redistributable gun recordings were reachable from this build environment (the shell reaches only GitHub and package registries; OpenGameArt, itch.io and Freesound pages can be read but their audio cannot be downloaded here). The CC0 set that was available contains impacts and interface sounds, not gunfire, so the weapons themselves remain synthesized layers. If you download a CC0 gun pack (for example from OpenGameArt) and upload it, it can be wired in as extra layers with its license recorded.
- **NOT VERIFIED**: all of this by ear; the occlusion on real maps (walls with thin or no collision will not muffle); performance of rendering the layers on a phone.
