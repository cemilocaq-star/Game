# Shooter sound-effect research and what OxenWar did with it

Honest scope: three sources were read in full (PC Gamer on Overwatch audio, Splice on weapon-sound layering, a CS2 sound-design article). Several more pages came up in searches (Call of Duty "most-heard sound", DICE Battlefield audio slides, Valorant/Apex footstep and settings guides, hit-marker articles) but only their titles were seen, so no claims below rest on them. Game sound files are copyrighted and were **not** copied or downloaded; everything added is synthesized from scratch in `scripts/sfx_bank.gd`.

| Game | Documented practice (source read) | Adapted to OxenWar | Status |
|---|---|---|---|
| Overwatch | Mix by importance (who looks at you, shoots you, how far), not just loudest-wins; sound paths give muffling around corners; friend/foe readable cues; filter chatter so only informative sounds play | Priority on the combat channel (kill > damage > hit); a hit tick never cuts a kill ding | Priority IMPLEMENTED; occlusion/pathing NOT IMPLEMENTED |
| Counter-Strike 2 | Footsteps tell direction, speed and distance; crouching/walking is quieter; gunfire identifies position and weapon; grenade/utility sounds signal pushes | OxenWar already has surface footsteps (grass/metal/wood/ice/stone) and 3D remote weapon audio | Existing, not changed |
| Generic layered weapon design (Splice) | Layers: mechanics, low end, close detail, far detail, tail; simplified non-player fire; vary pitch/volume and layers to avoid repetition | Existing weapon tones are procedural with pitch variation; layers were not rebuilt | NOT IMPLEMENTED (future) |
| Shooters in general | Short bright hit tick, distinct kill confirmation, low-health heartbeat, countdown ticks, accelerating bomb beeps | `hit`, `kill`, `damage`, `heartbeat`, `beep`, `tick` cues and `ui_hover`/`ui_click` for the menu | IMPLEMENTED and unit-tested |

## What was added

- `scripts/sfx_bank.gd`: eight original cues (tone bursts with decay, noise and harmonics), deterministic and cached.
- `scripts/sfx_director.gd`: plays hit/kill/damage from the local player's combat feedback, a heartbeat below 30 % health that speeds up as health falls, bomb beeps that accelerate as the fuse burns (and stop if match state stops arriving), and a tick for each of the last ten seconds.
- Menu hover/click sounds on every FPS-style button, nav tab and card (`FPS_UI.attach_sounds`).

## Not verified / limits

- Tests check the generated audio (format, length, peak, determinism) and the director's timing logic. **Nobody has listened to it**: loudness balance against gunfire and music, and whether the cues sound good, need ears on PC and phone.
- These are plain synthesized cues, not recordings; they will sound simpler than a commercial game. Licensed recordings (for example CC0 packs) can replace the generated streams later by changing `SFX_BANK.stream`.
- No meme sounds were added or generated.
