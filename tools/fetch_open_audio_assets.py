#!/usr/bin/env python3
"""Fetch and verify the project's redistributable CC0 event audio.

The game never downloads audio at runtime. This script is run by CI and can be
run locally once before opening/exporting the Godot project.
"""
from hashlib import sha256
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/blancmathis/Super_Bash_Folds/main/public/assets/audio/open/"
AUDIO = {
    "event-start.ogg": ("sfx/ready.ogg", "1b1211b6360aae37ea685fee057bcabd034a749c1dfac6a9d643086d96e9b9aa"),
    "event-freeze.ogg": ("sfx/countdown.ogg", "9d057b918024c787bbe6c00beed13a7ef72a3fa0c259add3cef36582792f4230"),
    "event-reward.ogg": ("sfx/item-pickup.ogg", "43d086d50f90493a98cd2e09aa6dbf150d164f1578e1ec768d21cb185571ad87"),
    "event-bonk.ogg": ("sfx/hit-heavy.ogg", "4ab53b26f4ea575120dcc1348526c9e0db2afc6af7a442aa0489bdead2ca80b6"),
    "event-end.ogg": ("sfx/game-set.ogg", "889d4c2b76c7edd63138b3a976c3f7337aaba3de90019d19bca70ec958c93014"),
    "event-music-loop.ogg": ("music/battle-loop.ogg", "5323dfe7f172e6b85870790f60027a533bd87bfd233e6c99cab0caf923f68f3f"),
}
LICENSES = {
    "KENNEY_IMPACT_SOUNDS.txt": "licenses/KENNEY_IMPACT_SOUNDS.txt",
    "KENNEY_MUSIC_JINGLES.txt": "licenses/KENNEY_MUSIC_JINGLES.txt",
    "KENNEY_INTERFACE_SOUNDS.txt": "licenses/KENNEY_INTERFACE_SOUNDS.txt",
}
LICENSES_BASE = "https://raw.githubusercontent.com/blancmathis/Super_Bash_Folds/main/public/assets/audio/"
USER_AGENT = "OxenWar-CC0-Asset-Setup/1.0"


def fetch(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=30) as response:
        if response.status != 200:
            raise RuntimeError(f"Download returned HTTP {response.status}: {url}")
        return response.read()


def write_verified(path: Path, payload: bytes, expected_hash: str) -> None:
    actual = sha256(payload).hexdigest()
    if actual != expected_hash:
        raise RuntimeError(f"SHA-256 mismatch for {path.name}: {actual}")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".download")
    temporary.write_bytes(payload)
    temporary.replace(path)


def main() -> None:
    destination = ROOT / "assets" / "audio"
    for filename, (relative_url, expected_hash) in AUDIO.items():
        payload = fetch(BASE + relative_url)
        write_verified(destination / filename, payload, expected_hash)
        print(f"VERIFIED {filename} sha256={expected_hash}")
    license_dir = destination / "licenses"
    license_dir.mkdir(parents=True, exist_ok=True)
    for filename, relative_url in LICENSES.items():
        payload = fetch(BASE + relative_url)
        if not payload.strip():
            raise RuntimeError(f"Empty license file: {filename}")
        (license_dir / filename).write_bytes(payload)
        print(f"LICENSE COPIED {filename}")
    source_licenses = fetch(LICENSES_BASE + "LICENSES.md")
    (license_dir / "UPSTREAM_AUDIO_SOURCES.md").write_bytes(source_licenses)
    print("Audio assets ready. No runtime downloads are required.")


if __name__ == "__main__":
    main()
