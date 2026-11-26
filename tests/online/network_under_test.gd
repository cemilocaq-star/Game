extends "res://scripts/oxenwar_network.gd"
## The real OxenWar network script with the two things that need the internet replaced, so a server
## and two clients can run on one machine over real UDP sockets:
##   - redeeming a game ticket (normally an HTTPS call to Supabase) accepts "TESTTICKET-<name>-..."
##   - saving the match result to Supabase is skipped
## Everything else (RPCs, rooms, input, hit validation, snapshots, reconciliation) is production code.
## This file lives in tests/ and is never loaded by the game.


func _redeem_game_ticket(ticket: String) -> Dictionary:
	var parts := ticket.split("-")
	if parts.size() < 3 or parts[0] != "TESTTICKET":
		return {"ok": false}
	var who := parts[1]
	return {
		"ok": true, "user_id": "test-user-" + who,
		"profile": {"display_name": "Test" + who, "avatar_color_id": "color_cyan"},
		"stats": {}, "session_token": "test-session-" + who,
	}


func _persist_session_result(_user_id: String, _session: Dictionary) -> void:
	return

func _persist_result_values(_user_id: String, _session_token: String, _score: int, _xp: int, _collections: Array, _kills: int, _deaths: int, _damage_dealt: float, _shots_fired: int, _shots_hit: int, _playtime_seconds: int, _outcome: String, _mastery_blaster_xp: int, _mastery_grenade_xp: int) -> bool:
	return true
