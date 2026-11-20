#!/usr/bin/env python3
"""Fetch and verify the project's redistributable CC0 event audio.

The game never downloads audio at runtime. This script is run by CI and can be
run locally once before opening/exporting the Godot project.
"""
from hashlib import sha256
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/blancmathis/Super_Bash_Folds/1028a3b739ef54efdcbe5a2ef0ad1714fe569c47/public/assets/audio/open/"
AUDIO = {
    "event-start.ogg": ("sfx/ready.ogg", "1b1211b6360aae37ea685fee057bcabd034a749c1dfac6a9d643086d96e9b9aa"),
    "event-freeze.ogg": ("sfx/countdown.ogg", "9d057b918024c787bbe6c00beed13a7ef72a3fa0c259add3cef36582792f4230"),
    "event-reward.ogg": ("sfx/item-pickup.ogg", "43d086d50f90493a98cd2e09aa6dbf150d164f1578e1ec768d21cb185571ad87"),
    "event-bonk.ogg": ("sfx/item-spawn.ogg", "2379b58f953e3d86982aa8cddcae763022c6258e9820171bf905ce58b4e97766"),
    "event-end.ogg": ("sfx/game-set.ogg", "889d4c2b76c7edd63138b3a976c3f7337aaba3de90019d19bca70ec958c93014"),
    "event-music-loop.ogg": ("music/battle-loop.ogg", "5323dfe7f172e6b85870790f60027a533bd87bfd233e6c99cab0caf923f68f3f"),
    "sfx/hit-light.ogg": ("sfx/hit-light.ogg", "d0bf60905b59ff630ffe01eb0edeeacd2504eaa8fb6523aeef7d2458b78264d3"),
    "sfx/hit-medium.ogg": ("sfx/hit-medium.ogg", "6492f9ccbc8d24dcef607bb1b48790b7870961474561f7fe5601e1c73a3018ef"),
    "sfx/hit-heavy.ogg": ("sfx/hit-heavy.ogg", "4ab53b26f4ea575120dcc1348526c9e0db2afc6af7a442aa0489bdead2ca80b6"),
    "sfx/land.ogg": ("sfx/land.ogg", "8b513c2f0316324060b9174b8f28df6c2147418c506e6a53b77f18e149a5547b"),
    "sfx/menu-move.ogg": ("sfx/menu-move.ogg", "ad09146e4ea33b931b2f5dfb4051a4f1fe4a36f1a48c42c5e9269c292ae21214"),
    "sfx/menu-confirm.ogg": ("sfx/menu-confirm.ogg", "33b17a9a9a2397c62b285c52c33a907fdffb476909c99e42dde603f6a7a8b12c"),
    "sfx/menu-back.ogg": ("sfx/menu-back.ogg", "61581c58194e3f19f531072edabbc344204c7e0a2887b8ededce4357bcf09195"),
    "sfx/respawn.ogg": ("sfx/respawn.ogg", "bcdca6b5c9c33aa15ca3fb18a1fa8d98a01b528b85be08c5a610e57c75fc022d"),
    "sfx/throw.ogg": ("sfx/throw.ogg", "9b1c35820fba507081261f19ab5f461f69a5e2627a7d91acdb73ca3cfc997979"),
}
LICENSES = {
    "KENNEY_IMPACT_SOUNDS.txt": "licenses/KENNEY_IMPACT_SOUNDS.txt",
    "KENNEY_MUSIC_JINGLES.txt": "licenses/KENNEY_MUSIC_JINGLES.txt",
    "KENNEY_INTERFACE_SOUNDS.txt": "licenses/KENNEY_INTERFACE_SOUNDS.txt",
}
LICENSES_BASE = "https://raw.githubusercontent.com/blancmathis/Super_Bash_Folds/1028a3b739ef54efdcbe5a2ef0ad1714fe569c47/public/assets/audio/"
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
