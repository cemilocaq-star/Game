#!/usr/bin/env python3
"""Regression tests for CI-generated Android version metadata."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS))
from set_android_version import update_android_version  # noqa: E402


class AndroidVersionTests(unittest.TestCase):
    def test_updates_only_android_preset_and_is_idempotent(self) -> None:
        source = (
            '[preset.0.options]\nversion/code=7\n\n'
            '[preset.1.options]\npackage/name="OxenWar"\n'
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "export_presets.cfg"
            path.write_text(source, encoding="utf-8")
            update_android_version(path, 356)
            update_android_version(path, 357)
            result = path.read_text(encoding="utf-8")

        self.assertIn("version/code=7", result)
        self.assertIn('version/code=357', result)
        self.assertIn('version/name="1.0.357"', result)
        self.assertEqual(result.count("version/code="), 2)
        self.assertEqual(result.count("version/name="), 1)

    def test_rejects_invalid_version_codes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "export_presets.cfg"
            path.write_text("[preset.1.options]\n", encoding="utf-8")
            for invalid in (0, -1, 2_100_000_001):
                with self.subTest(invalid=invalid):
                    with self.assertRaises(ValueError):
                        update_android_version(path, invalid)

    def test_requires_android_preset(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "export_presets.cfg"
            path.write_text("[preset.0.options]\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                update_android_version(path, 12)


if __name__ == "__main__":
    unittest.main(verbosity=2)
