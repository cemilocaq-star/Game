#!/usr/bin/env python3
"""Set a unique, monotonically increasing Android version for each CI build."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def update_android_version(path: Path, build_number: int) -> None:
    if not 1 <= build_number <= 2_100_000_000:
        raise ValueError("Android version code must be between 1 and 2,100,000,000")

    text = path.read_text(encoding="utf-8")
    marker = "[preset.1.options]"
    marker_index = text.find(marker)
    if marker_index < 0:
        raise ValueError("Android export preset [preset.1.options] was not found")

    section_start = marker_index + len(marker)
    next_section = re.search(r"(?m)^\[preset\.\d+(?:\.options)?\]\s*$", text[section_start:])
    section_end = section_start + next_section.start() if next_section else len(text)
    section = text[section_start:section_end]

    options = {
        "version/code": str(build_number),
        "version/name": f'"1.0.{build_number}"',
    }
    for key, value in options.items():
        pattern = re.compile(rf"(?m)^{re.escape(key)}=.*$")
        line = f"{key}={value}"
        if pattern.search(section):
            section = pattern.sub(lambda _match, replacement=line: replacement, section, count=1)
        else:
            if section and not section.endswith("\n"):
                section += "\n"
            section += line + "\n"

    path.write_text(text[:section_start] + section + text[section_end:], encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: set_android_version.py GITHUB_RUN_NUMBER", file=sys.stderr)
        return 2
    try:
        build_number = int(sys.argv[1])
        update_android_version(Path("export_presets.cfg"), build_number)
    except (ValueError, OSError) as exc:
        print(f"Could not set Android version: {exc}", file=sys.stderr)
        return 1
    print(f"Android version set to 1.0.{build_number} (version code {build_number})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
