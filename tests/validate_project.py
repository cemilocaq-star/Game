from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
errors = []

required = [
    "project.godot", "main.tscn", "scripts/main.gd", "scripts/player.gd",
    "scripts/oxenwar_supabase.gd", "scripts/oxenwar_menu.gd", "scripts/oxenwar_i18n.gd",
    "export_presets.cfg", "README.md", "docs/MIGRATION_AUDIT_AZ.md",
    "supabase/migrations/20261109114619_oxenwar_social_foundation.sql",
    "supabase/migrations/20261109114653_oxenwar_permissions_hardening.sql",
    "supabase/migrations/20261109114858_oxenwar_free_accessories.sql",
    "assets/LostFoodCourt_Arena_Blockout.glb", "assets/GoldenOrb_Collectible.glb",
    "assets/DuckBeacon_Mascot.glb", "assets/CosmicHalo_Cosmetic.glb",
    "scripts/progression.gd", "scripts/graphics_manager.gd", "shaders/neon_surface.gdshader",
]
for rel in required:
    if not (ROOT / rel).is_file():
        errors.append(f"missing: {rel}")

for rel in [
    "assets/LostFoodCourt_Arena_Blockout.glb", "assets/GoldenOrb_Collectible.glb",
    "assets/DuckBeacon_Mascot.glb", "assets/CosmicHalo_Cosmetic.glb",
]:
    path = ROOT / rel
    if path.exists():
        data = path.read_bytes()
        if len(data) < 12 or data[:4] != b"glTF" or struct.unpack_from("<I", data, 8)[0] != len(data):
            errors.append(f"invalid GLB header/length: {rel}")

def read(rel):
    path = ROOT / rel
    return path.read_text(encoding="utf-8") if path.exists() else ""

project = read("project.godot")
main = read("scripts/main.gd")
player = read("scripts/player.gd")
backend = read("scripts/oxenwar_supabase.gd")
menu = read("scripts/oxenwar_menu.gd")
i18n = read("scripts/oxenwar_i18n.gd")
workflow = read(".github/workflows/godot-ci.yml")
presets = read("export_presets.cfg")
readme = read("README.md")

checks = [
    ('config/name="OxenWar"', project, "OxenWar application name"),
    ("OxenWarMainMenu", main, "OxenWar menu integration"),
    ("OnlinePresenceHeartbeat", main, "presence heartbeat"),
    ("cosmetic_accessory", main, "player accessory integration"),
    ("_add_selected_accessory", player, "visible accessory customization"),
    ("friend_requests", backend, "friend request API"),
    ("refresh_token", backend, "session refresh"),
    ("PUBLISHABLE_KEY", backend, "Supabase publishable-key client"),
    ("accessory_id", menu, "accessory selection"),
    ("get_friend_presence", menu, "friend online/offline display"),
    ('"az"', i18n, "Azerbaijani localization"),
    ('"en"', i18n, "English localization"),
    ('"tr"', i18n, "Turkish localization"),
    ('"ru"', i18n, "Russian localization"),
    ("OxenWar.exe", presets, "OxenWar Windows export name"),
    ("OxenWar.apk", presets, "OxenWar Android export name"),
    ("OxenWar-Windows-x86_64", workflow, "OxenWar Windows artifact"),
    ("OxenWar-Android-arm64-debug", workflow, "OxenWar Android artifact"),
    ("single-player", readme, "multiplayer limitation documented"),
]
for needle, source, label in checks:
    if needle not in source:
        errors.append(f"missing {label}")

if "service_role" in backend.lower() or "sb_secret_" in backend:
    errors.append("secret/service-role credential must never be present in the game client")
if "ADMIN_CODE_SHA256" in main or "ADMIN_PLAYER_NAME" in main:
    errors.append("obsolete client-side admin password/name authorization remains")

if errors:
    print("VALIDATION FAILED")
    print("\n".join(f"- {error}" for error in errors))
    raise SystemExit(1)

print(f"VALIDATION PASSED: {len(required)} required files, 4 GLB headers, OxenWar identity, social/auth/cosmetic/localization hooks and export configuration checked")
print("NOTE: structural validation is not a Godot parse, runtime, online service, multiplayer or device test.")
