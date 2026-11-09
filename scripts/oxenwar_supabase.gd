extends Node
## Minimal native Godot client for the OxenWar Supabase project.
## Only the publishable key is embedded here; database access is protected by RLS.

const PROJECT_URL := "https://lznnfwhlsquiitkhjzlc.supabase.co"
const PUBLISHABLE_KEY := "sb_publishable_z7UuZtF9NQwox1Ae0droQA_mxpD-P7L"
const SESSION_PATH := "user://oxenwar_session.cfg"

var access_token := ""
var refresh_token := ""
var user_id := ""
var expires_at := 0

func _ready() -> void:
	pass

func restore_session() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SESSION_PATH) != OK:
		return {"ok": false, "message": "No saved session"}
	refresh_token = str(config.get_value("auth", "refresh_token", ""))
	if refresh_token.is_empty():
		return {"ok": false, "message": "No saved session"}
	access_token = str(config.get_value("auth", "access_token", ""))
	user_id = str(config.get_value("auth", "user_id", ""))
	expires_at = int(config.get_value("auth", "expires_at", 0))
	if expires_at <= int(Time.get_unix_time_from_system()) + 60:
		return await refresh_session()
	return {"ok": not access_token.is_empty(), "user_id": user_id}

func sign_up(email: String, password: String, display_name: String, username: String = "", locale: String = "en") -> Dictionary:
	var result := await _request(HTTPClient.METHOD_POST, "/auth/v1/signup", {
		"email": email.strip_edges(),
		"password": password,
		"data": {"display_name": display_name.strip_edges(), "username": username.strip_edges(), "locale": locale}
	})
	if not result.get("ok", false):
		return result
	_accept_auth_response(result.get("data", {}))
	if access_token.is_empty():
		return {"ok": true, "needs_email_confirmation": true, "message": "Check your email to confirm your account."}
	return {"ok": true, "user_id": user_id}

func sign_in(email: String, password: String) -> Dictionary:
	var result := await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {
		"email": email.strip_edges(),
		"password": password
	})
	if not result.get("ok", false):
		return result
	_accept_auth_response(result.get("data", {}))
	if access_token.is_empty():
		return {"ok": false, "message": "Supabase did not return an access token."}
	return {"ok": true, "user_id": user_id}

func refresh_session() -> Dictionary:
	if refresh_token.is_empty():
		return {"ok": false, "message": "Session expired. Please sign in again."}
	var result := await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {
		"refresh_token": refresh_token
	})
	if not result.get("ok", false):
		_clear_session()
		return result
	_accept_auth_response(result.get("data", {}))
	return {"ok": not access_token.is_empty(), "user_id": user_id}

func sign_out() -> void:
	if not access_token.is_empty():
		await _request(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, true)
	_clear_session()

func _accept_auth_response(data: Dictionary) -> void:
	access_token = str(data.get("access_token", access_token))
	refresh_token = str(data.get("refresh_token", refresh_token))
	var user: Dictionary = data.get("user", {})
	user_id = str(user.get("id", user_id))
	var lifetime := int(data.get("expires_in", 3600))
	expires_at = int(Time.get_unix_time_from_system()) + lifetime
	if not access_token.is_empty() and not refresh_token.is_empty():
		var config := ConfigFile.new()
		config.set_value("auth", "access_token", access_token)
		config.set_value("auth", "refresh_token", refresh_token)
		config.set_value("auth", "user_id", user_id)
		config.set_value("auth", "expires_at", expires_at)
		config.save(SESSION_PATH)

func _clear_session() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	expires_at = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

func _ensure_session() -> bool:
	if access_token.is_empty():
		return false
	if expires_at <= int(Time.get_unix_time_from_system()) + 60:
		var refreshed := await refresh_session()
		return refreshed.get("ok", false)
	return true

func _request(method: int, path: String, payload: Variant = null, authenticated: bool = false, extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	if authenticated:
		var valid_session: bool = await _ensure_session()
		if not valid_session:
			return {"ok": false, "message": "Please sign in again."}
	var request_node := HTTPRequest.new()
	request_node.timeout = 25.0
	add_child(request_node)
	var headers := PackedStringArray([
		"apikey: " + PUBLISHABLE_KEY,
		"Content-Type: application/json"
	])
	if authenticated and not access_token.is_empty():
		headers.append("Authorization: Bearer " + access_token)
	else:
		headers.append("Authorization: Bearer " + PUBLISHABLE_KEY)
	for header in extra_headers:
		headers.append(header)
	var body := "" if payload == null else JSON.stringify(payload)
	var request_error := request_node.request(PROJECT_URL + path, headers, method, body)
	if request_error != OK:
		request_node.queue_free()
		return {"ok": false, "message": "Network request could not start (%s)." % request_error}
	var response: Array = await request_node.request_completed
	request_node.queue_free()
	var response_code := int(response[1])
	var response_text := (response[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = {}
	if not response_text.is_empty():
		var parser := JSON.new()
		if parser.parse(response_text) == OK:
			parsed = parser.data
	if response_code >= 200 and response_code < 300:
		return {"ok": true, "data": parsed, "status": response_code}
	var message := "Request failed (%d)." % response_code
	if parsed is Dictionary:
		message = str(parsed.get("msg", parsed.get("message", parsed.get("error_description", parsed.get("error", message)))))
	return {"ok": false, "message": message, "status": response_code, "data": parsed}

func get_profile() -> Dictionary:
	if not await _ensure_session():
		return {}
	var result := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/profiles?select=id,username,display_name,locale,avatar_color_id,outfit_id,accessory_id&id=eq.%s&limit=1" % user_id, null, true)
	if not result.get("ok", false):
		return {}
	var rows: Array = result.get("data", [])
	return rows[0] if not rows.is_empty() else {}

func update_profile(changes: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_PATCH,
		"/rest/v1/profiles?id=eq.%s" % user_id, changes, true,
		PackedStringArray(["Prefer: return=representation"]))

func get_player_stats() -> Dictionary:
	if not await _ensure_session():
		return {"ok": false, "message": "Please sign in again."}
	var result := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/player_stats?select=total_score,best_score,total_xp,matches_played,total_kills,total_deaths,matches_won,matches_lost,matches_drawn,best_kills,best_damage,total_damage_dealt,total_shots_fired,total_shots_hit,total_playtime_seconds&user_id=eq.%s&limit=1" % user_id,
		null, true)
	if not result.get("ok", false):
		return result
	var rows: Array = result.get("data", [])
	return {"ok": true, "data": rows[0] if not rows.is_empty() else {}}

func get_weapon_mastery() -> Dictionary:
	if not await _ensure_session():
		return {"ok": false, "message": "Please sign in again."}
	var result := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/player_weapon_mastery?select=blaster_xp,grenade_xp,updated_at&user_id=eq.%s&limit=1" % user_id, null, true)
	if not result.get("ok", false):
		return result
	var rows: Array = result.get("data", [])
	return {"ok": true, "data": rows[0] if not rows.is_empty() else {"blaster_xp": 0, "grenade_xp": 0}}

func get_role() -> String:
	var result := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/player_roles?select=role&user_id=eq.%s&limit=1" % user_id, null, true)
	if not result.get("ok", false):
		return "player"
	var rows: Array = result.get("data", [])
	return str(rows[0].get("role", "player")) if not rows.is_empty() else "player"

func search_players(query: String) -> Dictionary:
	var term := query.strip_edges()
	if term.length() < 3:
		return {"ok": false, "message": "Enter at least 3 characters."}
	var encoded := term.uri_encode()
	return await _request(HTTPClient.METHOD_GET,
		"/rest/v1/profiles?select=id,username,display_name&username=ilike.*%s*&id=neq.%s&limit=20" % [encoded, user_id],
		null, true)

func send_friend_request(receiver_id: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/rest/v1/friend_requests",
		{"sender_id": user_id, "receiver_id": receiver_id}, true,
		PackedStringArray(["Prefer: return=representation"]))

func get_friend_requests() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET,
		"/rest/v1/friend_requests?select=id,sender_id,receiver_id,status,created_at&or=(sender_id.eq.%s,receiver_id.eq.%s)&status=eq.pending&order=created_at.desc" % [user_id, user_id],
		null, true)

func respond_friend_request(request_id: String, accepted: bool) -> Dictionary:
	var next_status := "accepted" if accepted else "rejected"
	return await _request(HTTPClient.METHOD_PATCH,
		"/rest/v1/friend_requests?id=eq.%s" % request_id, {"status": next_status}, true,
		PackedStringArray(["Prefer: return=representation"]))

func get_friends() -> Dictionary:
	var rows_result := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/friendships?select=user_a,user_b&or=(user_a.eq.%s,user_b.eq.%s)" % [user_id, user_id], null, true)
	if not rows_result.get("ok", false):
		return rows_result
	var friend_ids := PackedStringArray()
	for row in rows_result.get("data", []):
		var friend_id := str(row.get("user_b") if str(row.get("user_a")) == user_id else row.get("user_a"))
		friend_ids.append(friend_id)
	if friend_ids.is_empty():
		return {"ok": true, "data": []}
	var ids_filter := ",".join(friend_ids)
	return await _request(HTTPClient.METHOD_GET,
		"/rest/v1/profiles?select=id,username,display_name&id=in.(%s)" % ids_filter, null, true)

func get_cosmetics() -> Dictionary:
	var catalog := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/cosmetic_catalog?select=id,slot,name_key,color_hex,is_free&is_free=eq.true&order=slot,id", null, true)
	if not catalog.get("ok", false):
		return catalog
	var inventory := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/player_cosmetics?select=cosmetic_id&user_id=eq.%s" % user_id, null, true)
	if not inventory.get("ok", false):
		return inventory
	return {"ok": true, "catalog": catalog.get("data", []), "inventory": inventory.get("data", [])}

func update_presence() -> Dictionary:
	if user_id.is_empty():
		return {"ok": false, "message": "Not signed in."}
	return await _request(HTTPClient.METHOD_POST,
		"/rest/v1/online_presence?on_conflict=user_id",
		{"user_id": user_id, "last_seen_at": Time.get_datetime_string_from_system(true)},
		true, PackedStringArray(["Prefer: resolution=merge-duplicates,return=minimal"]))

func get_profile_by_id(profile_id: String) -> Dictionary:
	var result := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/profiles?select=id,username,display_name&id=eq.%s&limit=1" % profile_id, null, true)
	if not result.get("ok", false):
		return {}
	var rows: Array = result.get("data", [])
	return rows[0] if not rows.is_empty() else {}

func get_friend_presence(friend_ids: PackedStringArray) -> Dictionary:
	if friend_ids.is_empty():
		return {"ok": true, "data": []}
	return await _request(HTTPClient.METHOD_GET,
		"/rest/v1/online_presence?select=user_id,last_seen_at&user_id=in.(%s)" % ",".join(friend_ids),
		null, true)
