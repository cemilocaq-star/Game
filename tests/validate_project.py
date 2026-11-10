from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
errors = []

required = [
    "project.godot", "main.tscn", "scripts/main.gd", "scripts/player.gd", "scripts/arcade_weapon_visuals.gd", "scripts/character_visuals.gd", "scripts/character_motion_rig.gd", "scripts/combat_fx.gd",
    "scripts/oxenwar_supabase.gd", "scripts/oxenwar_menu.gd", "scripts/oxenwar_i18n.gd",
    "scripts/oxenwar_network.gd", "scripts/oxenwar_remote_player.gd", "scripts/oxenwar_server_player.gd", "server/README.md", "Dockerfile", "fly.toml", "render.yaml",
    "export_presets.cfg", "README.md", "docs/MIGRATION_AUDIT_AZ.md",
    "supabase/migrations/20261109114619_oxenwar_social_foundation.sql",
    "supabase/migrations/20261109114653_oxenwar_permissions_hardening.sql",
    "supabase/migrations/20261109123936_oxenwar_server_authoritative_stats.sql",
    "supabase/migrations/20261109124756_oxenwar_one_time_game_tickets.sql",
    "supabase/migrations/20261109125313_oxenwar_deny_client_ticket_access.sql",
    "supabase/config.toml",
    "supabase/functions/oxenwar-server-sync/index.ts",
    "supabase/functions/oxenwar-username-auth/index.ts",
    "supabase/migrations/20261109185916_oxenwar_username_only_auth.sql",
    "supabase/migrations/20261109114858_oxenwar_free_accessories.sql",
    "supabase/migrations/20261109143000_oxenwar_hero_inspired_outfits.sql",
    "supabase/migrations/20261109170000_oxenwar_career_statistics.sql",
    "assets/LostFoodCourt_Arena_Blockout.glb", "assets/GoldenOrb_Collectible.glb",
    "assets/DuckBeacon_Mascot.glb", "assets/CosmicHalo_Cosmetic.glb",
    "assets/audio/event-start.ogg", "assets/audio/event-freeze.ogg",
    "assets/audio/event-reward.ogg", "assets/audio/event-bonk.ogg",
    "assets/audio/event-end.ogg", "assets/audio/event-music-loop.ogg",
    "tools/fetch_open_audio_assets.py", "docs/EVENT_AUDIO_ASSETS.md",
    "scripts/progression.gd", "scripts/graphics_manager.gd", "scripts/oxenwar_event_fx.gd", "shaders/neon_surface.gdshader",
    "tools/set_android_version.py", "tests/test_android_version.py",
    "tests/test_live_websocket_proxy.py",
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
network = read("scripts/oxenwar_network.gd")
menu = read("scripts/oxenwar_menu.gd")
i18n = read("scripts/oxenwar_i18n.gd")
workflow = read(".github/workflows/godot-ci.yml")
presets = read("export_presets.cfg")
readme = read("README.md")

checks = [
    ('config/name="OxenWar"', project, "OxenWar application name"),
    ("textures/vram_compression/import_etc2_astc=true", project, "Android ETC2/ASTC texture import required by Godot export"),
    ("OxenWarMainMenu", main, "OxenWar menu integration"),
    ("OnlinePresenceHeartbeat", main, "presence heartbeat"),
    ('get_cmdline_user_args().has("--server")', main, "dedicated server entry point"),
    ("_start_multiplayer_client", main, "multiplayer client startup"),
    ("func _configured_server_host() -> String:", main, "server host configuration resolver"),
    ('ProjectSettings.get_setting("oxenwar/server_host", "")', main, "no implicit localhost multiplayer fallback"),
    ("MULTIPLAYER • Server not configured", main, "explicit multiplayer deployment status"),
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
    ('# The client sends its selected lobby action after receiving this result.', read("scripts/oxenwar_network.gd"), "server waits for selected lobby action instead of creating a phantom match"),

    ("issue_ticket", read("scripts/oxenwar_network.gd"), "HTTPS game ticket issuance"),
    ("HMAC", read("supabase/functions/oxenwar-server-sync/index.ts"), "signed one-time ticket validation"),
    ("oxenwar_game_tickets", read("supabase/migrations/20261109124756_oxenwar_one_time_game_tickets.sql"), "single-use ticket storage"),
    ("using (false)", read("supabase/migrations/20261109125313_oxenwar_deny_client_ticket_access.sql"), "explicit client denial on ticket tables"),
    ("check_friend", read("supabase/functions/oxenwar-server-sync/index.ts"), "server-side friendship check"),
    ("sync_result", read("supabase/functions/oxenwar-server-sync/index.ts"), "server-only result sync"),
    ("_server_join_room", read("scripts/oxenwar_network.gd"), "friend room join RPC"),
    ("_server_quick_match", read("scripts/oxenwar_network.gd"), "public matchmaking"),

    ("session_restored_on_auth", network, "client receives reconnect restoration state"),
    ("actions/cache@v4", workflow, "persistent Android debug signing key cache"),
    ("oxenwar-android-debug-keystore-v1", workflow, "stable Android signing cache key"),
    ("set_android_version.py", workflow, "unique Android version code per CI build"),
    ('"team_id": str(_server_players[peer_id].team_id)', network, "reconnect session stores team assignment"),
    ('player.team_id = restored_team if restored_team in ["red", "blue"] else ""', network, "reconnect restores validated team assignment"),
    ('"kill_streak": int(_server_players[peer_id].kill_streak)', network, "reconnect session stores kill streak"),
    ('player.stamina = clampf(float(restored.get("stamina", 100.0)), 0.0, 100.0)', network, "reconnect restores bounded stamina"),
    ('"secret_404_found": bool(_server_players[peer_id].secret_404_found)', network, "reconnect session stores secret collectible state"),
    ("if pending_launch_action.is_empty():", main, "reconnect does not blindly start a second match"),
    ("if not network.session_restored_on_auth:", main, "only new sessions are auto-queued after reconnect"),
    ("ROOM_GRACE_SECONDS := 30.0", read("scripts/oxenwar_network.gd"), "reconnect reservation"),
    ("orb_available", read("scripts/oxenwar_network.gd"), "server collectible state"),
    ("player_stats", read("supabase/migrations/20261109123936_oxenwar_server_authoritative_stats.sql"), "server-owned stats schema"),
    ("total_kills", read("supabase/migrations/20261109170000_oxenwar_career_statistics.sql"), "career kill aggregates"),
    ("matches_won", read("supabase/migrations/20261109170000_oxenwar_career_statistics.sql"), "career win/loss aggregates"),
    ("best_damage", read("supabase/migrations/20261109170000_oxenwar_career_statistics.sql"), "best match damage record"),
    ("get_player_stats", read("scripts/oxenwar_supabase.gd"), "career stats read API"),
    ("_render_stats", read("scripts/oxenwar_menu.gd"), "career statistics profile tab"),
    ("_rank_for_xp", read("scripts/oxenwar_menu.gd"), "XP-derived competitive rank"),
    ('"minimum":12000', read("scripts/oxenwar_menu.gd"), "Master rank XP threshold"),
    ("_render_rank_progress", read("scripts/oxenwar_menu.gd"), "rank progression UI"),
    ("match_xp", read("scripts/oxenwar_network.gd"), "server-authoritative per-match XP snapshot"),
    ("_rank_for_total_xp", read("scripts/main.gd"), "post-match rank transition calculation"),
    ("_add_match_xp_card", read("scripts/main.gd"), "match XP reward and rank badge UI"),
    ("RANK UP!", read("scripts/main.gd"), "rank-up celebration state"),
    ("round_match_xp += 100", read("scripts/main.gd"), "offline secret XP included in match reward"),
    ("rank_diamond", read("scripts/oxenwar_i18n.gd"), "localized rank labels"),

    ("p_playtime_seconds", read("supabase/functions/oxenwar-server-sync/index.ts"), "validated playtime persistence"),
    ("match_outcome = outcome", read("scripts/oxenwar_network.gd"), "server-derived win/loss outcome"),
    ("var match_outcome := \"abandoned\"", read("scripts/oxenwar_server_player.gd"), "per-match outcome state"),
    ("_persist_result_values", read("scripts/oxenwar_network.gd"), "server-side career result persistence"),

    ("oxenwar_apply_server_result", read("supabase/functions/oxenwar-server-sync/index.ts"), "server result persistence function"),
    ("OXENWAR_SERVER_SECRET", read("scripts/oxenwar_network.gd"), "server-only persistence secret"),
    ('if _server_secret.is_empty():', read("scripts/oxenwar_network.gd"), "dedicated server refuses missing authentication secret"),
    ('OXENWAR_SERVER_SECRET is required; refusing to start dedicated server.', read("scripts/oxenwar_network.gd"), "clear fail-closed server configuration error"),
    ('OS.get_environment("OXENWAR_TRANSPORT")', read("scripts/oxenwar_network.gd"), "configurable UDP or WebSocket transport"),
    ("WebSocketMultiplayerPeer.new()", read("scripts/oxenwar_network.gd"), "WebSocket multiplayer transport"),
    ('websocket_port := int(OS.get_environment("OXENWAR_PORT"))', read("scripts/oxenwar_network.gd"), "private Godot WebSocket port avoids Render public port conflict"),
    ('"GET /health "', read("server/render_entrypoint.py"), "Render HTTP health endpoint"),
    ("OXENWAR_GAME_PATH", read("server/render_entrypoint.py"), "Render entrypoint supports local CI project path"),
    ("asyncio.start_server(_handle_client, \"0.0.0.0\", PUBLIC_PORT)", read("server/render_entrypoint.py"), "public Render port bound on all interfaces"),
    ('"python3", "/game/server/render_entrypoint.py"', read("Dockerfile"), "container runs Render health and WebSocket proxy"),
    ("healthCheckPath: /health", read("render.yaml"), "Render blueprint checks the health endpoint"),

    ('websocket_peer.create_server(websocket_port, "0.0.0.0")', read("scripts/oxenwar_network.gd"), "hosted WebSocket server binds injected port"),
    ("websocket_peer.create_client(_last_host)", read("scripts/oxenwar_network.gd"), "client supports ws/wss URL"),

    ('Verify dedicated server rejects missing secret', workflow, "CI negative test for missing server secret"),
    ('ci-smoke-test-only-not-production', workflow, "CI server smoke test uses a non-production test secret"),
    ("FREEZE FRAME — MOVEMENT PAUSED", main, "freeze event localization label"),
    ("cosmetic_accessory", main, "player accessory integration"),
    ("_add_selected_accessory", player, "visible accessory customization"),
    ("friend_requests", backend, "friend request API"),
    ("refresh_token", backend, "session refresh"),
    ("PUBLISHABLE_KEY", backend, "Supabase publishable-key client"),
    ("/functions/v1/oxenwar-username-auth", backend, "username-only auth Edge Function client"),
    ('"action": "register"', backend, "username-only registration request"),
    ('"action": "login"', backend, "username-only login request"),
    ("oxenwar_lookup_auth_email", read("supabase/functions/oxenwar-username-auth/index.ts"), "server-side username-to-auth lookup"),
    ("oxenwar_consume_username_auth_attempt", read("supabase/functions/oxenwar-username-auth/index.ts"), "database-backed auth rate limiting"),
    ("createUser", read("supabase/functions/oxenwar-username-auth/index.ts"), "server-side account creation"),
    ("signInWithPassword", read("supabase/functions/oxenwar-username-auth/index.ts"), "server-side password verification"),
    ("accounts.oxenwar.invalid", read("supabase/functions/oxenwar-username-auth/index.ts"), "non-routable internal auth alias"),
    ("accessory_id", menu, "accessory selection"),
    ("outfit_iron_vanguard", player, "Iron Vanguard hero-inspired skin"),
    ("outfit_web_sentinel", player, "Web Sentinel hero-inspired skin"),
    ("outfit_id", read("scripts/oxenwar_network.gd"), "remote cosmetic replication"),
    ("team_deathmatch", read("scripts/oxenwar_network.gd"), "server-assigned team deathmatch mode"),
    ("king_of_the_hill", read("scripts/oxenwar_network.gd"), "server-authoritative King of the Hill mode"),
    ("hill_control", read("scripts/oxenwar_network.gd"), "server-side capture progress"),
    ("hill_points_red", read("scripts/oxenwar_network.gd"), "server-side red objective score"),
    ("hill_points_blue", read("scripts/oxenwar_network.gd"), "server-side blue objective score"),
    ("var kills := 0", read("scripts/oxenwar_server_player.gd"), "server-owned kill counter"),
    ("shooter.kills += 1", read("scripts/oxenwar_network.gd"), "kill credited on blaster elimination"),
    ("_server_players[owner_peer].kills += 1", read("scripts/oxenwar_network.gd"), "kill credited on grenade elimination"),
    ("kill_streak += 1", read("scripts/oxenwar_network.gd"), "server-owned consecutive kill counter"),
    ("best_kill_streak", read("scripts/oxenwar_server_player.gd"), "best match kill streak tracking"),
    ("_award_killstreak", read("scripts/oxenwar_network.gd"), "server-validated killstreak score bonuses"),
    ("_client_killstreak", read("scripts/oxenwar_network.gd"), "reliable killstreak announcement RPC"),
    ("KILL STREAK  x%d", read("scripts/main.gd"), "local killstreak HUD display"),
    ("DOMINATING", read("scripts/main.gd"), "killstreak milestone announcement"),
    ("blaster_mastery_xp", read("scripts/oxenwar_server_player.gd"), "server-owned blaster mastery XP"),
    ("grenade_mastery_xp", read("scripts/oxenwar_server_player.gd"), "server-owned grenade mastery XP"),
    ("_award_weapon_mastery", read("scripts/oxenwar_network.gd"), "mastery XP awarded only from validated combat events"),
    ("WEAPON MASTERY", read("scripts/main.gd"), "live weapon mastery HUD"),
    ("_weapon_mastery_rank", read("scripts/main.gd"), "mastery rank thresholds"),
    ("ARCADE_WEAPONS", read("scripts/oxenwar_network.gd"), "server-side arcade weapon registry"),
    ("_server_select_weapon", read("scripts/oxenwar_network.gd"), "server-validated weapon selection"),
    ("star_piercer", read("scripts/oxenwar_network.gd"), "precision arcade weapon archetype"),
    ("duck_launcher", read("scripts/oxenwar_network.gd"), "comedic duck weapon archetype"),
    ("banana_boomerang", read("scripts/oxenwar_network.gd"), "comedic boomerang weapon archetype"),
    ("confetti_cannon", read("scripts/oxenwar_network.gd"), "comedic confetti weapon archetype"),
    ("request_select_weapon", read("scripts/main.gd"), "weapon selection UI integration"),
    ("weapon_next", read("scripts/main.gd"), "mobile and keyboard weapon cycling"),
    ("oxenwar_apply_weapon_mastery", read("supabase/migrations/20261109193000_oxenwar_weapon_mastery.sql"), "service-role-only persistent weapon mastery RPC"),
    ("player_weapon_mastery", read("supabase/migrations/20261109193000_oxenwar_weapon_mastery.sql"), "persistent weapon mastery table"),
    ("get_weapon_mastery", read("scripts/oxenwar_supabase.gd"), "authenticated persistent mastery read API"),
    ("_render_weapon_mastery", read("scripts/oxenwar_menu.gd"), "career mastery panel"),
    ("weapon_mastery_persistence_failed", read("supabase/functions/oxenwar-server-sync/index.ts"), "mastery persistence failure surfaced"),
    ("\"kills\": player.kills", read("scripts/oxenwar_network.gd"), "authoritative kill leaderboard snapshots"),
    ("MATCH RESULTS", main, "unified FFA, Team Deathmatch and King of the Hill results screen"),
    ("KING OF THE HILL", main, "King of the Hill lobby selector"),
    ("Hill_North_Beam", main, "central capture-zone arena marker"),
    ("objective_label.text", main, "live hill objective HUD"),
    ("WINNER  %s  •  %d KILLS", main, "highest-kill winner announcement"),
    ("play_emote(\"griddy\")", player, "Griddy emote trigger"),
    ("play_emote(\"goofy\")", player, "goofy dance emote trigger"),
    ("_make_emote_music", player, "original synthesized emote music"),
    ("LOOP_FORWARD", player, "looped original dance beat"),
    ("request_emote", read("scripts/oxenwar_network.gd"), "network emote request"),
    ("emote_id", read("scripts/oxenwar_network.gd"), "replicated emote state"),
    
    
    
    
    ("emote_robot", player, "robot emote input"),
    ("emote_wave", player, "wave emote input"),
    ('net.request_emote("")', player, "server receives emote stop state"),
    ('"robot"', read("scripts/oxenwar_network.gd"), "server validates robot emote"),
    ('"wave"', read("scripts/oxenwar_network.gd"), "server validates wave emote"),
    ('"collections": player.collection_counts.duplicate(true)', read("scripts/oxenwar_network.gd"), "authoritative collectible count snapshot"),
    ('"secret_404_found": player.secret_404_found', read("scripts/oxenwar_network.gd"), "authoritative secret discovery snapshot"),
    ("GOLD ORBS (XP ONLY)", main, "clear non-currency orb counter"),
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
    ("BarrelShroud", read("scripts/arcade_weapon_visuals.gd"), "multi-part Aether Blaster barrel casing"),
    ("UpperPowerRail", read("scripts/arcade_weapon_visuals.gd"), "Aether Blaster top equipment rail"),
    ("MuzzleRing", read("scripts/arcade_weapon_visuals.gd"), "Aether Blaster muzzle detail"),
    ("_blaster_recoil", player, "short visual blaster recoil animation"),
    ("_make_weapon_stream(weapon_id: String)", player, "original weapon-specific synthesized audio"),
    ("_fire_blaster", player, "local blaster firing"),
    ("MOUSE_BUTTON_LEFT", main, "desktop blaster input"),
    ('"FIRE"', main, "mobile primary-action control"),
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
checks.extend([
    ('window/stretch/aspect="expand"', project, "mobile ultrawide aspect expansion"),
    ("window/handheld/orientation=4", project, "sensor-locked landscape mobile orientation"),
    ("DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)", main, "fixed runtime landscape orientation lock"),
    ("window/energy_saving/keep_screen_on=true", project, "keep phone display awake during play"),
    ("window/frame_pacing/android/enable_frame_pacing=true", project, "Android frame pacing"),
    ('Verify Android package, architecture and debug signature', workflow, "post-export Android APK verification"),
    ('"$AAPT" dump badging build/OxenWar.apk', workflow, "APK package metadata inspection"),
    ('"$APKSIGNER" verify --verbose --print-certs build/OxenWar.apk', workflow, "APK signature and certificate fingerprint verification"),
    ("native-code: 'arm64-v8a'", workflow, "ARM64 APK architecture check"),
    ("build/OxenWar.apk.sha256", workflow, "APK SHA-256 sidecar artifact"),
    ("_build_touch_controls(root)", main, "mobile touch controls integration"),
    ("_render_play_tab()", menu, "pre-game lobby and matchmaking menu"),
    ("_is_server_address_valid", menu, "server address validation before matchmaking"),
    ("_is_valid_room_code", menu, "room code alphabet and length validation"),
    ('_t("start_match")', menu, "localized start-match action label"),
    ('_t("create_room")', menu, "localized room creation action label"),
    ('_t("join_room")', menu, "localized room joining action label"),
    ('_launch_game.bind("quick_match")', menu, "start action launches public quick matchmaking"),
    ('_launch_game.bind("create_room")', menu, "create room reaches the room creation flow"),
    ('_launch_game.bind("join_room")', menu, "join room reaches the room joining flow"),
    ('_t("server_missing")', menu, "menu explicitly reports missing public server configuration"),

    ('_t("mode_ffa")', menu, "localized matchmaking game mode"),
    ('_t("server_missing")', menu, "localized missing-server state"),




    ("_launch_game.bind(\"quick_match\")", menu, "menu quick-match intent is passed into gameplay"),
    ("pending_launch_action", main, "game applies the selected menu matchmaking action after server authentication"),
    ("network.request_create_room(true, selected_game_mode)", main, "main menu room creation reaches the authoritative server"),
    ("network.request_quick_match(selected_game_mode)", main, "main menu matchmaking reaches the authoritative server"),


    ("class MobileJoystick extends Control", main, "custom circular analog movement joystick"),
    ("StandoffStyleMovementJoystick", main, "Standoff-style joystick UI"),
    ("_set_mobile_move_input", main, "analog joystick maps to analog movement actions"),
    ('Input.action_release("move_right")', main, "joystick releases old horizontal direction before reversing"),
    ('Input.action_release("move_left")', main, "joystick releases opposite horizontal direction before pressing"),
    ('Input.action_release("move_back")', main, "joystick releases old vertical direction before reversing"),
    ('func _exit_tree() -> void:', main, "joystick releases movement actions when removed from scene"),
    ('event.canceled', main, "joystick handles cancelled touch input without sticking"),

    ("func _build_emote_wheel", main, "mobile radial emote menu"),
    ("EmoteRadialWheel", main, "radial emote wheel instead of separate square buttons"),
    ("func _add_touch_button", main, "rounded mobile action button construction"),
    ("Input.action_press(action)", main, "touch hold press maps to gameplay action"),
    ("Input.action_release(action)", main, "touch release clears gameplay action"),
    ("InputEventScreenDrag", player, "touch-drag camera look"),
    ("Input.get_gyroscope()", player, "optional Android gyro camera look"),
    ("SCOREBOARD", main, "mobile scoreboard control"),
    ("CharacterVisuals.build(_body_mesh", player, "shared local character detail model"),
    ("_set_visual_layer_recursive(self, 2)", player, "hide local avatar from first-person camera"),
    ("_camera.cull_mask = 1", player, "first-person camera renders world and weapon but not local avatar"),
    ("_add_selected_accessory()", player, "accessories visible with every outfit"),
    ("_build_character_preview_stage", menu, "live 3D character customization viewport"),
    ("_refresh_character_preview", menu, "real-time cosmetic preview updates"),
    ("CHARACTER_VISUALS.build(body, outfit_id, avatar_color)", menu, "preview reuses actual in-game character model details"),
    ("preview_spin.rotation.y += delta", menu, "rotating character showcase"),
    ("SubViewportContainer", menu, "character customization 3D preview container"),
    ("CharacterVisuals.build(_visual", read("scripts/oxenwar_remote_player.gd"), "shared remote character detail model"),
    ("TacticalVest", read("scripts/character_visuals.gd"), "layered tactical vest mesh"),
    ("BootSole", read("scripts/character_visuals.gd"), "separate boot and sole geometry"),
    ("Backpack", read("scripts/character_visuals.gd"), "backpack silhouette detail"),
    ("grenade_explosion", read("scripts/combat_fx.gd"), "layered grenade explosion visual"),
    ("ExpandingShockRing", read("scripts/combat_fx.gd"), "grenade shockwave ring"),
    ("ImpactCore", read("scripts/combat_fx.gd"), "weapon-aware arcade impact core visual"),
    ("COMBAT_FX_SCRIPT.grenade_explosion", main, "grenade explosion FX integration"),
    ("COMBAT_FX_SCRIPT.hit_impact", main, "remote blaster impact FX integration"),
    ("ProceduralMotionRig", read("scripts/character_motion_rig.gd"), "procedural animated limb rig"),
    ("ArmPivot_L", read("scripts/character_motion_rig.gd"), "left arm animation pivot"),
    ("LegPivot_R", read("scripts/character_motion_rig.gd"), "right leg animation pivot"),
    ("CharacterMotionRig.animate", player, "local procedural movement animation"),
    ("CombatStatusPanel", main, "framed combat HUD panel"),
    ("VitalsPanel", main, "framed health and stamina HUD panel"),
    ("LobbyPanel", main, "framed lobby HUD panel"),
    ("_style_progress_bar", main, "custom HUD progress bar styling"),
    ("MATCH SCOREBOARD", main, "in-game match scoreboard"),
    ("_refresh_scoreboard", main, "live scoreboard refresh"),
    ("_on_kill_feed_received", main, "client kill feed display"),
    ("KEY_TAB", main, "desktop scoreboard toggle"),
    ("var deaths := 0", read("scripts/oxenwar_server_player.gd"), "server-owned death counter"),
    ("\"deaths\": player.deaths", read("scripts/oxenwar_network.gd"), "authoritative death snapshots"),
    ("_broadcast_kill_feed", read("scripts/oxenwar_network.gd"), "server-authoritative elimination event"),
    ("_client_kill_feed", read("scripts/oxenwar_network.gd"), "reliable kill feed RPC"),
    ("var shots_fired := 0", read("scripts/oxenwar_server_player.gd"), "server-owned blaster shot counter"),
    ("shooter.shots_hit += 1", read("scripts/oxenwar_network.gd"), "server-confirmed hit accuracy"),
    ("damage_dealt", read("scripts/oxenwar_network.gd"), "server-authoritative damage statistics"),
    ("shots_fired", read("scripts/oxenwar_network.gd"), "authoritative combat statistics snapshots"),
    ("MATCH RESULTS", main, "expanded end-of-match results screen"),
    ("WEAPON ACCURACY", main, "personal accuracy calculation across the expanded weapon roster"),
    ("MVP  •", main, "match MVP announcement"),
    ("RED TEAM WINS", main, "team deathmatch team result"),
    ("CharacterMotionRig.animate", read("scripts/oxenwar_remote_player.gd"), "remote procedural movement animation"),
    ("_build_swimming_pool", main, "visible beach pool area"),
    ("_build_arena_detail_pass", main, "procedural arena art detail pass"),
    ("FloorGridX_", main, "floor inlay detail"),
    ("CornerBeaconLight", main, "arena corner lighting"),
    ("TONE_MAPPER_FILMIC", read("scripts/graphics_manager.gd"), "filmic graphics tonemapping"),
    ("glow_enabled", read("scripts/graphics_manager.gd"), "quality-scaled glow"),
    ("surface_detail", read("shaders/neon_surface.gdshader"), "procedural surface microdetail"),
    ("BeachSwimwear", player, "local beach outfit visual"),
    ("SwimShorts", player, "swim shorts mesh"),
    ("set_swimming", player, "local swimwear state toggle"),
    ("is_swimming", read("scripts/oxenwar_server_player.gd"), "server-authoritative swim-zone state"),
    ("is_swimming", read("scripts/oxenwar_network.gd"), "multiplayer swimwear replication"),
    ("_build_remote_swimwear", read("scripts/oxenwar_remote_player.gd"), "remote beach outfit visual"),
])

checks.extend([
    ("func inspect_weapon() -> void:", player, "weapon inspect animation action"),
    ("_make_weapon_stream(weapon_id: String)", player, "weapon-specific synthetic audio generator"),
    ('"aether":[260.0, 105.0, 520.0, 0.22]', player, "Aether Blaster synthesized pulse audio profile"),
    ('"rubber_chicken":[390.0, 720.0, 1170.0, 0.42]', player, "Rubber Chicken distinct audio profile"),
    ('"star_piercer":[780.0, 620.0, 1560.0, 0.08]', player, "Star Piercer distinct audio profile"),
    ("KEY_H", main, "keyboard weapon inspect shortcut"),
    ("INSPECT  [H]", main, "arsenal weapon inspect control"),
    ("_inspect_current_weapon", main, "inspect UI action routing"),
    ("func _animate_weapon_fire() -> void:", player, "weapon-family firing animation"),
    ('"comet_bow", "star_piercer", "solar_lance"', player, "precision archetype firing animation"),
    ('"prism_scepter", "frost_wand", "jellyfish_staff"', player, "staff archetype firing animation"),
    ("ArcadeWeaponImpactFX_", read("scripts/combat_fx.gd"), "weapon-specific impact effects"),
    ('shard_shape = "pixel"', read("scripts/combat_fx.gd"), "pixel/glitch impact variant"),
    ('shard_shape = "bubble"', read("scripts/combat_fx.gd"), "bubble/slime impact variant"),
    ("weapon_id, beam_color", main, "impact receives authoritative weapon identity and palette"),
])
new_weapon_ids = ["prism_scepter", "vortex_orbiter", "comet_bow", "bubble_burst", "glitch_ray", "meteor_mallet", "frost_wand", "solar_lance", "slime_slinger", "pixel_storm", "thunder_drum", "moon_disc", "jellyfish_staff", "portal_popper", "rubber_chicken"]
if len(new_weapon_ids) != 15:
    errors.append("expected exactly 15 new arcade weapon archetypes")
for weapon_id in new_weapon_ids:
    checks.append((f'"{weapon_id}"', read("scripts/oxenwar_network.gd"), f"server weapon registry: {weapon_id}"))
    checks.append((f'"{weapon_id}"', player, f"local weapon profile: {weapon_id}"))
    checks.append((f'"{weapon_id}"', read("scripts/arcade_weapon_visuals.gd"), f"procedural weapon silhouette: {weapon_id}"))
if "ARSENAL  •  23" not in main or "_build_arsenal_panel" not in main:
    errors.append("23-slot arcade arsenal selection screen is missing")
if "set_selected_weapon" not in player or "ARCADE_WEAPON_VISUALS.build_weapon" not in player:
    errors.append("weapon equip flow does not rebuild the selected first-person model")

for needle, source, label in checks:
    if needle not in source:
        errors.append(f"missing {label}")

if 'ProjectSettings.get_setting("oxenwar/server_host", "127.0.0.1")' in main or 'else "127.0.0.1"' in main:
    errors.append("multiplayer client must not default to localhost when no dedicated server is configured")
if "email_input" in menu:
    errors.append("email field remains in the account UI")
if "/auth/v1/signup" in backend or "/auth/v1/token?grant_type=password" in backend:
    errors.append("game client still calls email-based Supabase Auth endpoints directly")
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
