extends RefCounted
## The game's audio buses, so different kinds of sound can be set apart from each other.
##
##   Master
##    |- SFX     world sounds with a position: gunfire, explosions, footsteps. Carries the room reverb.
##    |- Events  one-shot cues of the map events (frost, meteors ...).
##    |- Music   event music, ambience and the emote beat.
##    |- UI      menu sounds and the combat feedback ticks (hit, kill, damage).
##
## Every bus sends to Master, so the master volume in the settings still controls everything. A player
## whose bus does not exist plays on Master, so nothing is lost if ensure() has not run yet.

const SFX := "SFX"
const WEAPONS := "Weapons"
const FOOTSTEPS := "Footsteps"
const EVENTS := "Events"
const MUSIC := "Music"
const UI := "UI"
const ALL := [SFX, EVENTS, MUSIC, UI, WEAPONS, FOOTSTEPS]
const ROOM_REVERB_NAME := "RoomReverb"


## Creates the buses that are missing. Safe to call any number of times. Returns how many it made.
static func ensure() -> int:
	var made := 0
	for bus_name in ALL:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, SFX if bus_name in [WEAPONS, FOOTSTEPS] else "Master")
		made += 1
	var sfx := AudioServer.get_bus_index(SFX)
	if sfx >= 0 and room_reverb() == null:
		var reverb := AudioEffectReverb.new()
		reverb.resource_name = ROOM_REVERB_NAME
		reverb.room_size = 0.2
		reverb.damping = 0.6
		reverb.wet = 0.0
		reverb.dry = 1.0
		reverb.spread = 1.0
		reverb.hipass = 0.0
		AudioServer.add_bus_effect(sfx, reverb)
	for bus_name in ALL:
		var settings := preload("res://scripts/user_settings.gd")
		settings.apply_bus_volume(bus_name, settings.bus_volume(bus_name))
	return made


## The reverb on the SFX bus, or null when the bus is not set up.
static func room_reverb() -> AudioEffectReverb:
	var sfx := AudioServer.get_bus_index(SFX)
	if sfx < 0:
		return null
	for index in range(AudioServer.get_bus_effect_count(sfx)):
		var effect := AudioServer.get_bus_effect(sfx, index)
		if effect is AudioEffectReverb and effect.resource_name == ROOM_REVERB_NAME:
			return effect as AudioEffectReverb
	return null


## The bus name to use for a player, falling back to Master when that bus is not set up.
static func bus_or_master(bus_name: String) -> StringName:
	return StringName(bus_name) if AudioServer.get_bus_index(bus_name) >= 0 else &"Master"
