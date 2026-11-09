from pathlib import Path
import json
import struct

ROOT = Path(__file__).resolve().parents[1]
errors = []
required = [
    "project.godot", "main.tscn", "scripts/main.gd", "scripts/player.gd",
    "export_presets.cfg", "README.md", "docs/MIGRATION_AUDIT_AZ.md",
    "assets/LostFoodCourt_Arena_Blockout.glb", "assets/GoldenOrb_Collectible.glb",
    "assets/DuckBeacon_Mascot.glb", "assets/CosmicHalo_Cosmetic.glb",
]
for rel in required:
    if not (ROOT / rel).is_file():
        errors.append(f"missing: {rel}")

for rel in ["assets/LostFoodCourt_Arena_Blockout.glb", "assets/GoldenOrb_Collectible.glb", "assets/DuckBeacon_Mascot.glb", "assets/CosmicHalo_Cosmetic.glb"]:
    p = ROOT / rel
    if p.exists():
        data = p.read_bytes()
        if len(data) < 12 or data[:4] != b"glTF" or struct.unpack_from("<I", data, 8)[0] != len(data):
            errors.append(f"invalid GLB header/length: {rel}")

main_script = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
player_script = (ROOT / "scripts/player.gd").read_text(encoding="utf-8")
presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
for needle, text, label in [
    ("_build_arena", main_script, "arena builder"),
    ("_build_collectibles", main_script, "collectible builder"),
    ("_start_random_event", main_script, "event rotation"),
    ("try_dash", player_script, "dash mechanic"),
    ("_set_sliding", player_script, "actual slide stance"),
    ("JUMP_BUFFER_TIME", player_script, "jump input buffer"),
    ("COYOTE_TIME", player_script, "coyote-time jump window"),
    ("_finish_round", main_script, "round completion screen"),
    ("ROUND COMPLETE", main_script, "round results UI"),
    ("Input.get_gyroscope", player_script, "mobile gyro path"),
    ('name="Windows Desktop"', presets, "Windows export preset"),
    ('name="Android"', presets, "Android export preset"),
]:
    if needle not in text:
        errors.append(f"missing {label}")

if errors:
    print("VALIDATION FAILED")
    print("\n".join(f"- {e}" for e in errors))
    raise SystemExit(1)
print(f"VALIDATION PASSED: {len(required)} required paths, 4 GLB headers, gameplay hooks and both local export presets checked")
print("NOTE: this is a structural check, not a Godot parse, runtime, network, or platform-build test.")
