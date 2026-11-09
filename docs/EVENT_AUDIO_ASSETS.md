# OxenWar event audio — sources and licenses

## Integrated open assets

The build setup downloads a small set of event cues and one low-volume background loop from the open-audio folder in [blancmathis/Super_Bash_Folds](https://github.com/blancmathis/Super_Bash_Folds/tree/1028a3b739ef54efdcbe5a2ef0ad1714fe569c47/public/assets/audio). The source repository's audio provenance file identifies the selected Kenney sound packs and the music loop's source.

- **Event start** (event-start.ogg), **freeze cue** (event-freeze.ogg), **reward cue** (event-reward.ogg), **Bonk-mode arcade cue** (event-bonk.ogg), and **round/event end** (event-end.ogg): selected from Kenney's CC0 audio collections. The upstream provenance record includes Impact Sounds, Interface Sounds, and Music Jingles, and the corresponding license notices are retained.
- **Background loop** (event-music-loop.ogg): “Two Simple Game Music Loops” by qubodup, CC0 1.0, sourced through the upstream repository's provenance record.

The original license notices are copied into assets/audio/licenses/ when the setup script runs. The fetch script pins SHA-256 hashes and fails if a downloaded file differs. Audio is downloaded at setup/build time only; the shipped game does not make audio requests to the internet.

## Setup

Run from the repository root before opening/exporting the project:

~~~bash
python3 tools/fetch_open_audio_assets.py
~~~

CI runs the same script before validation and export. No YouTube audio is copied: only assets with a documented redistributable license are used.

## Notes

The event visuals are original procedural Godot meshes/particles and the existing DuckBeacon GLB; they are not claimed to be custom AAA animated character models. The synthesized event motif remains in the project and is layered with the licensed low-volume loop and event cues.
