extends SceneTree
## Feedback sounds: every cue is generated, audible, not clipped, deterministic, the right length,
## and the director's timing helpers behave (heartbeat speeds up, bomb beeps accelerate, countdown).

const BANK := preload("res://scripts/sfx_bank.gd")
const DIRECTOR := preload("res://scripts/sfx_director.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _peak(wav: AudioStreamWAV) -> float:
	var peak := 0.0
	for index in range(wav.data.size() / 2):
		peak = maxf(peak, absf(float(wav.data.decode_s16(index * 2)) / 32768.0))
	return peak


func _run() -> void:
	var lengths := {}
	for id in BANK.IDS:
		var wav: AudioStreamWAV = BANK.stream(id)
		_check(wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS and not wav.stereo, "%s is 16-bit mono" % id)
		var seconds := float(wav.data.size() / 2) / float(wav.mix_rate)
		lengths[id] = seconds
		_check(seconds >= 0.03 and seconds <= 0.9, "%s has a sensible length (%f s)" % [id, seconds])
		var peak := _peak(wav)
		_check(peak > 0.5 and peak <= 1.0, "%s is audible and not clipped (peak %f)" % [id, peak])
		_check(BANK.stream(id) == wav, "%s is cached" % id)
	_check(float(lengths["kill"]) > float(lengths["hit"]), "the kill cue is longer than the hit tick")
	_check(float(lengths["heartbeat"]) >= 0.35, "the heartbeat holds two thumps")
	_check(float(lengths["ui_hover"]) < float(lengths["ui_click"]) + 0.02, "hover is the lightest interface sound")
	# Deterministic: the same cue always renders the same bytes.
	BANK._cache.clear()
	var again: AudioStreamWAV = BANK.stream("kill")
	BANK._cache.clear()
	_check(again.data == BANK.stream("kill").data, "synthesis is deterministic")

	_check(DIRECTOR.heartbeat_interval(5.0) < DIRECTOR.heartbeat_interval(29.0), "the heartbeat speeds up as health falls")
	_check(DIRECTOR.heartbeat_interval(100.0) == DIRECTOR.heartbeat_interval(30.0), "no change above the low-health threshold")
	_check(DIRECTOR.bomb_interval(2.0) < DIRECTOR.bomb_interval(8.0) and DIRECTOR.bomb_interval(8.0) < DIRECTOR.bomb_interval(30.0), "bomb beeps accelerate as the fuse burns")
	_check(DIRECTOR.bomb_interval(0.0) >= 0.12, "bomb beeps never exceed the maximum rate")

	var director := DIRECTOR.new()
	root.add_child(director)
	director.set_round_left(11.2)
	director.set_round_left(9.6)
	_check(director.get("_last_whole") == 10, "the countdown tracks whole seconds")
	director.set_low_health(20.0, true)
	_check(director.get("_heartbeat_on"), "low health starts the heartbeat")
	director.set_low_health(20.0, false)
	_check(not director.get("_heartbeat_on"), "a dead player has no heartbeat")
	director.set_low_health(80.0, true)
	_check(not director.get("_heartbeat_on"), "healthy players have no heartbeat")
	director.set_bomb_fuse(20.0)
	director.call("_process", 0.016)
	_check(float(director.get("_bomb_fuse")) < 20.0, "the bomb fuse counts down locally between snapshots")
	director.call("_process", 2.0)
	_check(float(director.get("_bomb_fuse")) < 0.0, "stale bomb state stops the beeping")
	director.play("hit")
	director.play("kill")
	director.play("hit")
	var combat: AudioStreamPlayer = director.get("_channels").get("combat")
	_check(combat != null and str(combat.get_meta("sfx_id")) == "kill", "a hit tick does not cut a kill ding short")
	director.free()

	if failures.is_empty():
		print("PASS: feedback sound bank and director timing")
		await process_frame
		await process_frame
		for test_node in root.get_children():
			if test_node is AudioStreamPlayer:
				test_node.stop()
				test_node.stream = null
			test_node.queue_free()
		await process_frame
		await process_frame
		await create_timer(0.15).timeout
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		await process_frame
		await process_frame
		for test_node in root.get_children():
			if test_node is AudioStreamPlayer:
				test_node.stop()
				test_node.stream = null
			test_node.queue_free()
		await process_frame
		await process_frame
		await create_timer(0.15).timeout
		quit(1)
