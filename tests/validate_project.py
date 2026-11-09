from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
errors = []

required = [
    "project.godot", "main.tscn", "scripts/main.gd", "scripts/player.gd",
    "scripts/oxenwar_supabase.gd", "scripts/oxenwar_menu.gd", "scripts/oxenwar_i18n.gd",
    "scripts/oxenwar_network.gd", "scripts/oxenwar_remote_player.gd", "scripts/oxenwar_server_player.gd", "server/README.md", "Dockerfile", "fly.toml",
    "export_presets.cfg", "README.md", "docs/MIGRATION_AUDIT_AZ.md",
    "supabase/migrations/20261109114619_oxenwar_social_foundation.sql",
    "supabase/migrations/20261109114653_oxenwar_permissions_hardening.sql",
    "supabase/migrations/20261109123936_oxenwar_server_authoritative_stats.sql",
    "supabase/migrations/20261109124756_oxenwar_one_time_game_tickets.sql",
    "supabase/migrations/20261109125313_oxenwar_deny_client_ticket_access.sql",
    "supabase/config.toml",
    "supabase/functions/oxenwar-server-sync/index.ts",
    "supabase/migrations/20261109114858_oxenwar_free_accessories.sql",
    "supabase/migrations/20261109143000_oxenwar_hero_inspired_outfits.sql",
    "assets/LostFoodCourt_Arena_Blockout.glb", "assets/GoldenOrb_Collectible.glb",
    "assets/DuckBeacon_Mascot.glb", "assets/CosmicHalo_Cosmetic.glb",
    "assets/audio/event-start.ogg", "assets/audio/event-freeze.ogg",
    "assets/audio/event-reward.ogg", "assets/audio/event-bonk.ogg",
    "assets/audio/event-end.ogg", "assets/audio/event-music-loop.ogg",
    "tools/fetch_open_audio_assets.py", "docs/EVENT_AUDIO_ASSETS.md",
    "scripts/progression.gd", "scripts/graphics_manager.gd", "scripts/oxenwar_event_fx.gd", "shaders/neon_surface.gdshader",
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
    ('get_cmdline_user_args().has("--server")', main, "dedicated server entry point"),
    ("_start_multiplayer_client", main, "multiplayer client startup"),
    ("_on_remote_player_state", main, "remote player rendering"),
    ('@rpc("any_peer", "call_remote", "unreliable_ordered")', read("scripts/oxenwar_network.gd"), "server movement RPC"),
    ("MAX_CLIENTS := 32", read("scripts/oxenwar_network.gd"), "dedicated server capacity"),
    ("_server_submit_input", read("scripts/oxenwar_network.gd"), "server-owned input handling"),
    ("move_and_slide()", read("scripts/oxenwar_server_player.gd"), "server-side physics simulation"),
    ("FREEZE_FRAME", read("scripts/oxenwar_network.gd"), "server-scheduled freeze event"),
    ("_build_event_artifact", read("scripts/oxenwar_event_fx.gd"), "event-specific animated 3D centerpiece"),
    ("event-freeze.ogg", read("scripts/oxenwar_event_fx.gd"), "freeze event sound cue"),
    ("event-reward.ogg", read("scripts/oxenwar_event_fx.gd"), "reward event sound cue"),
    ("event-music-loop.ogg", read("scripts/oxenwar_event_fx.gd"), "licensed event music loop"),
    ("_detect_footstep_surface", player, "surface-aware footstep detection"),
    ("_make_footstep_stream", player, "procedural surface footstep SFX"),
    ("SurfaceFootstepAudio", player, "3D positional footstep audio"),
    ("OriginalEventSynth", read("scripts/oxenwar_event_fx.gd"), "original synthesized event audio"),
    ("FREEZE_FRAME", read("scripts/oxenwar_server_player.gd"), "server-authoritative freeze event"),
    ("FrostedArenaFloor", read("scripts/oxenwar_event_fx.gd"), "ice event visuals"),
    ("_start_synth_music", read("scripts/oxenwar_event_fx.gd"), "original event audio"),
    ("_redeem_game_ticket", read("scripts/oxenwar_network.gd"), "one-time ticket redemption"),
    ("issue_ticket", read("scripts/oxenwar_network.gd"), "HTTPS game ticket issuance"),
    ("HMAC", read("supabase/functions/oxenwar-server-sync/index.ts"), "signed one-time ticket validation"),
    ("oxenwar_game_tickets", read("supabase/migrations/20261109124756_oxenwar_one_time_game_tickets.sql"), "single-use ticket storage"),
    ("using (false)", read("supabase/migrations/20261109125313_oxenwar_deny_client_ticket_access.sql"), "explicit client denial on ticket tables"),
    ("check_friend", read("supabase/functions/oxenwar-server-sync/index.ts"), "server-side friendship check"),
    ("sync_result", read("supabase/functions/oxenwar-server-sync/index.ts"), "server-only result sync"),
    ("_server_join_room", read("scripts/oxenwar_network.gd"), "friend room join RPC"),
    ("_server_quick_match", read("scripts/oxenwar_network.gd"), "public matchmaking"),
    ("ROOM_GRACE_SECONDS := 30.0", read("scripts/oxenwar_network.gd"), "reconnect reservation"),
    ("orb_available", read("scripts/oxenwar_network.gd"), "server collectible state"),
    ("player_stats", read("supabase/migrations/20261109123936_oxenwar_server_authoritative_stats.sql"), "server-owned stats schema"),
    ("oxenwar_apply_server_result", read("supabase/functions/oxenwar-server-sync/index.ts"), "server result persistence function"),
    ("OXENWAR_SERVER_SECRET", read("scripts/oxenwar_network.gd"), "server-only persistence secret"),
    ("FREEZE FRAME — MOVEMENT PAUSED", main, "freeze event localization label"),
    ("cosmetic_accessory", main, "player accessory integration"),
    ("_add_selected_accessory", player, "visible accessory customization"),
    ("friend_requests", backend, "friend request API"),
    ("refresh_token", backend, "session refresh"),
    ("PUBLISHABLE_KEY", backend, "Supabase publishable-key client"),
    ("accessory_id", menu, "accessory selection"),
    ("outfit_iron_vanguard", player, "Iron Vanguard hero-inspired skin"),
    ("outfit_web_sentinel", player, "Web Sentinel hero-inspired skin"),
    ("outfit_id", read("scripts/oxenwar_network.gd"), "remote cosmetic replication"),
    ("team_deathmatch", read("scripts/oxenwar_network.gd"), "server-assigned team deathmatch mode"),
    ("var kills := 0", read("scripts/oxenwar_server_player.gd"), "server-owned kill counter"),
    ("shooter.kills += 1", read("scripts/oxenwar_network.gd"), "kill credited on blaster elimination"),
    ("_server_players[owner_peer].kills += 1", read("scripts/oxenwar_network.gd"), "kill credited on grenade elimination"),
    ("\"kills\": player.kills", read("scripts/oxenwar_network.gd"), "authoritative kill leaderboard snapshots"),
    ("FREE FOR ALL • MATCH COMPLETE", main, "FFA match winner screen"),
    ("WINNER  %s  •  %d KILLS", main, "highest-kill winner announcement"),
    ("_server_throw_grenade", read("scripts/oxenwar_network.gd"), "server-validated grenade throw"),
    ("_server_detonate_grenade", read("scripts/oxenwar_network.gd"), "server-authoritative grenade blast"),
    ("_server_step_grenades", read("scripts/oxenwar_network.gd"), "server grenade fuse and movement"),
    ("Dust2_A_Site", main, "original Dust II-inspired map geometry"),
    ("get_friend_presence", menu, "friend online/offline display"),
    ('"az"', i18n, "Azerbaijani localization"),
    ('"en"', i18n, "English localization"),
    ('"tr"', i18n, "Turkish localization"),
    ('"ru"', i18n, "Russian localization"),
    ("_setup_blaster", player, "procedural Aether Blaster model"),
    ("_make_blaster_stream", player, "original sci-fi pulse audio"),
    ("_fire_blaster", player, "local blaster firing"),
    ("MOUSE_BUTTON_LEFT", main, "desktop blaster input"),
    ('"PULSE"', main, "mobile blaster control"),
    ("_server_blaster_fire", read("scripts/oxenwar_network.gd"), "server-validated blaster fire"),
    ("_client_blaster_fx", read("scripts/oxenwar_network.gd"), "multiplayer blaster visual replication"),
    ("_last_blaster_ms", read("scripts/oxenwar_network.gd"), "server fire-rate validation"),
    ("apply_damage", read("scripts/oxenwar_server_player.gd"), "server health and death state"),
    ("respawn_at", read("scripts/oxenwar_server_player.gd"), "automatic respawn"),
    ('"health": player.health', read("scripts/oxenwar_network.gd"), "authoritative health snapshots"),
    ("health_bar", main, "health HUD bar"),
    ("K.O.", main, "local death and respawn notice"),
    ("_make_remote_blaster_stream", main, "remote positional blaster audio"),
    ("RemoteAetherPulseAudio", main, "3D remote blaster sound source"),
    ("OxenWar.exe", presets, "OxenWar Windows export name"),
    ("OxenWar.apk", presets, "OxenWar Android export name"),
    ("OxenWar-Windows-x86_64", workflow, "OxenWar Windows artifact"),
    ("OxenWar-Android-arm64-debug", workflow, "OxenWar Android artifact"),
    ("multiplayer", readme.lower(), "multiplayer scope documented"),
    ("CharacterBody3D movement", read("server/README.md"), "authoritative physics documented"),
    ("friendship", read("server/README.md"), "friend-only room admission documented"),
    ("OXENWAR_SERVER_SECRET", read("server/README.md"), "persistence secret setup documented"),
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

print(f"VALIDATION PASSED: {len(required)} required files, 4 GLB headers, OxenWar identity, authenticated authoritative multiplayer, social/cosmetic/localization hooks and export configuration checked")
print("NOTE: structural validation is not a Godot parse, runtime, online service, multiplayer or device test.")
