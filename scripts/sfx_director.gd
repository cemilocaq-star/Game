extends Node
## In-match feedback audio: hit/kill confirmation, damage, low-health heartbeat, bomb beeps and
## the last-ten-seconds countdown. Priorities: kill > damage > hit > everything else, so a kill
## ding is never buried by a hit tick (louder, and it replaces a quieter sound on its channel).

const SFX_BANK := preload("res://scripts/sfx_bank.gd")
const LOW_HEALTH := 30.0
const STALE_SECONDS := 1.5

var _channels: Dictionary = {} # id group -> AudioStreamPlayer
var _heartbeat_on := false
var _heartbeat_health := 100.0
var _heartbeat_left := 0.0
var _bomb_fuse := -1.0
var _bomb_left := 0.0
var _bomb_age := 0.0
var _last_whole := -1

const VOLUME := {"hit": -7.0, "kill": -3.0, "damage": -4.0, "heartbeat": -8.0, "beep": -9.0, "tick": -10.0}
## Recorded CC0 impact layered under the synthesized cue: [file, volume dB].
const RECORDED_LAYER := {"hit": ["hit-light", -11.0], "damage": ["hit-medium", -9.0], "kill": ["hit-heavy", -9.0]}


static func heartbeat_interval(health: float) -> float:
	return lerpf(1.1, 0.55, clampf(1.0 - health / LOW_HEALTH, 0.0, 1.0))


static func bomb_interval(fuse_seconds: float) -> float:
	return clampf(fuse_seconds / 12.0, 0.12, 1.0)


func play(id: String) -> void:
	var group := "combat" if id in ["hit", "kill", "damage"] else id
	var player: AudioStreamPlayer = _channels.get(group)
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "Sfx_" + group
		add_child(player)
		_channels[group] = player
	# A kill ding may interrupt a hit tick, but a hit tick never cuts a kill ding short.
	if id == "hit" and player.playing and str(player.get_meta("sfx_id", "")) in ["kill", "damage"]:
		return
	player.set_meta("sfx_id", id)
	player.stream = SFX_BANK.stream(id)
	player.volume_db = float(VOLUME.get(id, -8.0))
	player.pitch_scale = randf_range(0.97, 1.03)
	player.play()
	if RECORDED_LAYER.has(id):
		play_recorded(str(RECORDED_LAYER[id][0]), float(RECORDED_LAYER[id][1]), "layer_" + group)


## Plays a recorded CC0 sound on its own channel (respawn, throw ...).
func play_recorded(sound_name: String, volume_db: float = -8.0, channel: String = "recorded") -> void:
	var sound := SFX_BANK.recorded(sound_name)
	if sound == null:
		return
	var player: AudioStreamPlayer = _channels.get(channel)
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "Sfx_" + channel
		add_child(player)
		_channels[channel] = player
	player.stream = sound
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.98, 1.02)
	player.play()


func set_low_health(health: float, alive: bool) -> void:
	_heartbeat_on = alive and health > 0.0 and health < LOW_HEALTH
	_heartbeat_health = health


## fuse_seconds < 0 means no bomb is ticking.
func set_bomb_fuse(fuse_seconds: float) -> void:
	_bomb_fuse = fuse_seconds
	_bomb_age = 0.0


func set_round_left(seconds: float) -> void:
	var whole := int(ceil(seconds))
	if whole != _last_whole:
		_last_whole = whole
		if seconds > 0.0 and whole >= 1 and whole <= 10:
			play("tick")


func _process(delta: float) -> void:
	if _heartbeat_on:
		_heartbeat_left -= delta
		if _heartbeat_left <= 0.0:
			_heartbeat_left = heartbeat_interval(_heartbeat_health)
			play("heartbeat")
	else:
		_heartbeat_left = 0.0
	_bomb_age += delta
	if _bomb_fuse >= 0.0 and _bomb_age > STALE_SECONDS:
		_bomb_fuse = -1.0 # the match state stopped arriving (left the match)
	if _bomb_fuse >= 0.0:
		_bomb_fuse = maxf(0.0, _bomb_fuse - delta)
		_bomb_left -= delta
		if _bomb_left <= 0.0:
			_bomb_left = bomb_interval(_bomb_fuse)
			play("beep")
	else:
		_bomb_left = 0.0
