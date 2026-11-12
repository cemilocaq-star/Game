extends RefCounted
## Original cartoon troll character pass shared by local and remote avatars.
## Uses smooth rounded meshes, expressive faces and non-combat costume details.
##
## Three hand-built troll characters have a full costume profile:
##   outfit_runner    -> Golden Pilot Troll   (gold skin, leather aviator cap, goggles, scarf)
##   outfit_ghost_ops -> Ghost-Ops Troll      (pale skin, balaclava, skull mask, tactical vest)
##   outfit_neon      -> Neon Cyan Riot Troll (cyan skin, riot helmet + visor, armor, shield)
## The profile table below is the single source of truth for their colors; the
## procedural motion rig reads it so arms, legs and feet match the costume.

const PROFILE_OUTFITS := ["outfit_runner", "outfit_ghost_ops", "outfit_neon"]

## Hero-inspired skins that add armor pieces on top of the shared torso.
const HERO_OUTFITS := ["outfit_iron_vanguard", "outfit_web_sentinel"]

## Body proportions shared by every outfit (relative to the body node, which
## stands 0.9 above the ground). A slim torso keeps the oversized head, arms and
## legs visible and puts the soles at ground level. The collision capsule in
## the player scripts is separate and unchanged.
const TROLL_BODY_RADIUS := 0.29
const TROLL_BODY_HEIGHT := 0.65
const TROLL_HEAD_Y := 0.70
const TROLL_SHOULDER_X := 0.34
const TROLL_SHOULDER_Y := 0.17
const TROLL_HIP_Y := -0.057


static func has_character_profile(outfit_id: String) -> bool:
	return outfit_id in PROFILE_OUTFITS


## Costume colors and flags for the three signature characters.
## Returns an empty Dictionary for every other outfit (default, hero skins).
static func profile_for(outfit_id: String) -> Dictionary:
	match outfit_id:
		"outfit_runner":
			return {
				"skin": Color("#D9AE2F"),
				"suit": Color("#6B4326"),
				"trim": Color("#EAC36D"),
				"sleeve": Color("#6B4326"),
				"hand": Color("#D9AE2F"),
				"thigh": Color("#5E5A32"),
				"shin": Color("#D9AE2F"),
				"joint": Color("#4A2E1C"),
				"foot": "bare",
				"knee_pad": false,
			}
		"outfit_ghost_ops":
			return {
				"skin": Color("#E9E8E2"),
				"suit": Color("#1C1F22"),
				"trim": Color("#C9D3D6"),
				"sleeve": Color("#E9E8E2"),
				"hand": Color("#141618"),
				"thigh": Color("#202426"),
				"shin": Color("#E9E8E2"),
				"joint": Color("#2B3033"),
				"foot": "flipflop",
				"knee_pad": false,
			}
		"outfit_neon":
			return {
				"skin": Color("#36D6E0"),
				"suit": Color("#23272D"),
				"trim": Color("#5BFFFF"),
				"sleeve": Color("#2A2F36"),
				"hand": Color("#36D6E0"),
				"thigh": Color("#2A2F36"),
				"shin": Color("#1D2126"),
				"joint": Color("#3A4048"),
				"foot": "boot",
				"knee_pad": true,
			}
	return {}


## Body (capsule) color for an outfit. Falls back to the player's chosen color
## for outfits without a costume profile.
static func suit_color_for(outfit_id: String, fallback: Color) -> Color:
	var profile := profile_for(outfit_id)
	if profile.is_empty():
		return fallback
	var suit: Color = profile["suit"]
	return suit


## Sets the visual body capsule. Every outfit shares the slim torso, so the
## limb rig, head and costume pieces line up the same way for all of them.
static func apply_body_shape(body: MeshInstance3D, _outfit_id: String = "") -> void:
	var capsule := body.mesh as CapsuleMesh
	if capsule == null:
		return
	capsule.radius = TROLL_BODY_RADIUS
	capsule.height = TROLL_BODY_HEIGHT


static func is_hero_outfit(outfit_id: String) -> bool:
	return outfit_id in HERO_OUTFITS


static func build(parent: Node3D, outfit_id: String, base_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CharacterDetailPass"
	parent.add_child(root)

	var styled := has_character_profile(outfit_id)
	var masked_mouth := outfit_id == "outfit_ghost_ops"
	var skin := _skin_for_outfit(outfit_id)
	var fabric_color := base_color
	var fabric_light := _material(fabric_color.lightened(0.24), 0.04, 0.82)
	var trim := _material(_trim_for_outfit(outfit_id, base_color), 0.18, 0.48)
	var skin_material := _material(skin, 0.0, 0.82)
	var skin_shadow := _material(skin.darkened(0.18), 0.0, 0.88)
	var white := _material(Color("#FFF9E9"), 0.0, 0.35)
	var pupil := _material(Color("#162231"), 0.04, 0.25)
	var mouth := _material(Color("#492A34"), 0.0, 0.8)
	var tongue := _material(Color("#F18A9D"), 0.0, 0.62)
	var blush := _material(Color("#E98A83"), 0.0, 0.82)
	var dark := _material(Color("#24303A"), 0.12, 0.68)

	# The signature trolls use their own gear instead of the generic tunic. The slim body
	# capsule itself is the tunic, so only the surface details are added on top of it.
	if not styled:
		_add_ellipsoid(root, "TunicFrontPanel", 0.205, Vector3(1.12, 1.12, 0.30), Vector3(0.0, 0.03, -0.235), fabric_light)
		_add_capsule(root, "SoftCollar", 0.105, 0.18, Vector3(0.0, 0.335, -0.045), trim)
		_add_ellipsoid(root, "WaistBand", 0.22, Vector3(1.05, 0.27, 0.70), Vector3(0.0, -0.285, -0.035), dark)
		_add_ellipsoid(root, "RoundBuckle", 0.055, Vector3(1.0, 0.92, 0.42), Vector3(0.0, -0.285, -0.205), trim)
		for index in range(3):
			_add_ellipsoid(root, "TunicButton_%d" % index, 0.025, Vector3.ONE, Vector3(0.0, 0.12 - float(index) * 0.105, _front_z(0.0, TROLL_BODY_RADIUS) - 0.012), trim)
		_add_ellipsoid(root, "FriendlyBadge", 0.06, Vector3(1.0, 1.0, 0.45), Vector3(-0.145, 0.115, -0.253), trim)
		_add_ellipsoid(root, "TunicHem", 0.22, Vector3(1.08, 0.18, 0.70), Vector3(0.0, -0.285, -0.045), fabric_light)
		# Rounded shoulder caps and hip pouches keep the silhouette rich without blocky armor.
		for side in [-1.0, 1.0]:
			var shoulder := _add_ellipsoid(root, "SoftShoulderPad_%s" % str(side), 0.105, Vector3(1.22, 0.78, 0.92), Vector3(side * 0.30, 0.225, -0.01), trim)
			shoulder.rotation.z = side * -0.18
			_add_ellipsoid(root, "BeltPouch_%s" % str(side), 0.062, Vector3(0.78, 0.92, 0.68), Vector3(side * 0.205, -0.27, -0.12), dark)

	# Oversized head pivot makes the avatar read as a playful troll from every angle.
	var head := Node3D.new()
	head.name = "HeadPivot"
	head.position = Vector3(0.0, TROLL_HEAD_Y, 0.0)
	root.add_child(head)
	_add_ellipsoid(head, "TrollHead", 0.30, Vector3(1.02, 1.05, 0.90), Vector3.ZERO, skin_material)
	_add_ellipsoid(head, "LowerJaw", 0.205, Vector3(1.04, 0.62, 0.80), Vector3(0.0, -0.145, -0.018), skin_shadow)

	# Soft, pointed ears with rounded tips.
	for side in [-1.0, 1.0]:
		var ear := _add_ellipsoid(head, "TrollEar_%s" % str(side), 0.13, Vector3(1.25, 0.62, 0.52), Vector3(side * 0.275, -0.015, -0.005), skin_material)
		ear.rotation.z = -side * 0.22
		var inner_ear := _add_ellipsoid(head, "InnerEar_%s" % str(side), 0.065, Vector3(1.0, 0.50, 0.30), Vector3(side * 0.292, -0.015, -0.081), blush)
		inner_ear.rotation.z = -side * 0.22

	# Large eyes, pupils and expressive brows.
	for side in [-1.0, 1.0]:
		_add_ellipsoid(head, "EyeWhite_%s" % str(side), 0.078, Vector3(1.0, 1.12, 0.66), Vector3(side * 0.102, 0.055, -0.247), white)
		_add_ellipsoid(head, "EyeIris_%s" % str(side), 0.045, Vector3(0.95, 1.0, 0.55), Vector3(side * 0.091, 0.048, -0.291), trim)
		_add_ellipsoid(head, "EyePupil_%s" % str(side), 0.024, Vector3(0.92, 1.0, 0.50), Vector3(side * 0.087, 0.044, -0.315), pupil)
		_add_ellipsoid(head, "EyeSparkle_%s" % str(side), 0.012, Vector3.ONE, Vector3(side * 0.078 - 0.012, 0.066, -0.329), white)
		var brow := _add_capsule(head, "ExpressiveBrow_%s" % str(side), 0.032, 0.13, Vector3(side * 0.105, 0.16, -0.245), skin_shadow)
		brow.rotation.z = side * -0.16
		_add_ellipsoid(head, "RosyCheek_%s" % str(side), 0.045, Vector3(1.1, 0.52, 0.35), Vector3(side * 0.19, -0.105, -0.229), blush)

	_add_ellipsoid(head, "TrollNose", 0.06, Vector3(1.12, 0.82, 0.76), Vector3(0.0, -0.045, -0.30), skin_material)
	if not masked_mouth:
		_add_ellipsoid(head, "Smile", 0.092, Vector3(1.25, 0.48, 0.46), Vector3(0.0, -0.185, -0.267), mouth)
		_add_ellipsoid(head, "Tongue", 0.052, Vector3(1.0, 0.50, 0.38), Vector3(0.0, -0.215, -0.292), tongue)
		for side in [-1.0, 1.0]:
			_add_ellipsoid(head, "SmileTooth_%s" % str(side), 0.031, Vector3(0.72, 0.86, 0.54), Vector3(side * 0.035, -0.157, -0.304), white)

	if styled:
		# Hair is hidden under each costume's cap, hood or helmet.
		_add_character_gear(root, head, outfit_id)
	else:
		_add_hair(head, outfit_id, skin, trim)
		_add_headwear(head, outfit_id, trim, dark)
	return root


## Iron Vanguard / Web Sentinel armor, fitted to the slim torso and shared by the
## local player, remote players and the customization preview. Original rounded
## silhouettes only; no copied movie/game meshes or logos. Returns the root of
## the added pieces, or null for any outfit that is not a hero skin.
static func add_hero_details(parent: Node3D, outfit_id: String) -> Node3D:
	if not is_hero_outfit(outfit_id):
		return null
	var iron := outfit_id == "outfit_iron_vanguard"
	var primary := Color("#A92332") if iron else Color("#B52D3D")
	var secondary := Color("#D9B45B") if iron else Color("#183D78")
	var glow := Color("#66EFFF") if iron else Color("#E34A62")
	var armor := _material(secondary, 0.55, 0.28)
	var shell := _material(primary, 0.42, 0.28)
	var accent := _glow_material(glow, 1.8)

	var root := Node3D.new()
	root.name = "HeroArmor"
	parent.add_child(root)

	_add_ellipsoid(root, "HeroChestPlate", 0.25, Vector3(1.08, 0.88, 0.42), Vector3(0.0, 0.05, -0.25), armor)
	var core_radius := 0.105 if iron else 0.075
	_add_ellipsoid(root, "HeroCore", core_radius, Vector3(1.0, 1.0, 0.55), Vector3(0.0, 0.08, -0.33), accent)
	for side in [-1.0, 1.0]:
		_add_ellipsoid(root, "HeroShoulder_" + _side_suffix(side), 0.16, Vector3(1.0, 0.78, 0.82), Vector3(side * TROLL_SHOULDER_X, TROLL_SHOULDER_Y + 0.03, 0.0), armor)

	# Dome over the upper head with a glowing visor band at eye level.
	_add_ellipsoid(root, "HeroHelmet", 0.31, Vector3(1.0, 0.62, 0.90), Vector3(0.0, TROLL_HEAD_Y + 0.15, 0.0), shell)
	_add_ellipsoid(root, "HeroVisor", 0.16, Vector3(1.12, 0.40, 0.28), Vector3(0.0, TROLL_HEAD_Y + 0.065, -0.285), accent)

	if not iron:
		for side in [-1.0, 1.0]:
			_add_capsule(root, "HeroWebLine_" + _side_suffix(side), 0.012, 0.40, Vector3(side * 0.12, 0.05, -0.36), _material(Color("#DDEBFF"), 0.0, 0.65))
	return root


static func _skin_for_outfit(outfit_id: String) -> Color:
	var profile := profile_for(outfit_id)
	if not profile.is_empty():
		var profile_skin: Color = profile["skin"]
		return profile_skin
	match outfit_id:
		"outfit_iron_vanguard":
			return Color("#A8C95D")
		"outfit_web_sentinel":
			return Color("#A579C9")
		_:
			return Color("#75BD5A")


static func _trim_for_outfit(outfit_id: String, base_color: Color) -> Color:
	var profile := profile_for(outfit_id)
	if not profile.is_empty():
		var profile_trim: Color = profile["trim"]
		return profile_trim
	match outfit_id:
		"outfit_iron_vanguard":
			return Color("#F1C85E")
		"outfit_web_sentinel":
			return Color("#D6A1F4")
		_:
			return base_color.lightened(0.38)


static func _add_hair(head: Node3D, outfit_id: String, skin: Color, trim: Material) -> void:
	var hair_color := Color("#3B4A2B") if outfit_id == "outfit_default" else skin.darkened(0.38)
	var hair_material := _material(hair_color, 0.02, 0.86)
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var tuft := _add_ellipsoid(head, "HairTuft_%d" % index, 0.11, Vector3(0.74, 1.24, 0.74), Vector3(cos(angle) * 0.17, 0.23 + (0.04 if index % 2 == 0 else 0.0), sin(angle) * 0.13), hair_material)
		tuft.rotation.z = -0.18 if index % 2 == 0 else 0.18
	_add_ellipsoid(head, "HairCrown", 0.15, Vector3(1.18, 0.50, 1.05), Vector3(0.0, 0.235, 0.025), hair_material)


static func _add_headwear(head: Node3D, outfit_id: String, trim: Material, dark: Material) -> void:
	if outfit_id == "outfit_iron_vanguard":
		for index in range(3):
			var crown_piece := _add_ellipsoid(head, "GoldenCrown_%d" % index, 0.07, Vector3(0.82, 1.65, 0.72), Vector3((float(index) - 1.0) * 0.12, 0.30, 0.0), trim)
			crown_piece.rotation.z = (float(index) - 1.0) * -0.15
	elif outfit_id == "outfit_web_sentinel":
		var band := _add_capsule(head, "VioletHeadband", 0.04, 0.46, Vector3(0.0, 0.18, -0.015), trim)
		band.rotation.z = deg_to_rad(90.0)


# ---------------------------------------------------------------------------
# Signature troll characters
# ---------------------------------------------------------------------------

static func _add_character_gear(root: Node3D, head: Node3D, outfit_id: String) -> void:
	match outfit_id:
		"outfit_runner":
			_add_pilot_gear(root, head)
		"outfit_ghost_ops":
			_add_ghost_gear(root, head)
		"outfit_neon":
			_add_riot_gear(root, head)


## Golden Pilot Troll: bomber jacket (the body capsule), fleece collar, white
## scarf, olive shorts and a leather aviator cap with brass goggles.
static func _add_pilot_gear(root: Node3D, head: Node3D) -> void:
	var body_radius := TROLL_BODY_RADIUS
	var leather := _material(Color("#4A2E1C"), 0.06, 0.62)
	var leather_light := _material(Color("#8A5A32"), 0.06, 0.60)
	var fleece := _material(Color("#E8DCB8"), 0.0, 0.95)
	var scarf := _material(Color("#F4F1E6"), 0.0, 0.85)
	var brass := _material(Color("#D9AE3F"), 0.70, 0.28)
	var olive := _material(Color("#5E5A32"), 0.02, 0.80)
	var lens := _glass_material(Color("#4FA8C8"), 0.62)
	var ivory := _material(Color("#F4EBD0"), 0.0, 0.45)

	_add_torus(root, "PilotFleeceCollar", 0.13, 0.31, Vector3(0.0, 0.34, 0.0), fleece)
	_add_torus(root, "PilotScarf", 0.11, 0.25, Vector3(0.0, 0.40, 0.0), scarf)
	for index in range(2):
		var tail := _add_ellipsoid(root, "ScarfTail_%d" % index, 0.075, Vector3(0.75, 2.6, 0.16), Vector3(0.08 + float(index) * 0.10, 0.22 - float(index) * 0.05, 0.31), scarf)
		tail.rotation = Vector3(0.30 + float(index) * 0.12, 0.0, 0.10 - float(index) * 0.22)
	_add_torus(root, "PilotBelt", 0.26, 0.35, Vector3(0.0, -0.12, 0.0), leather)
	_add_ellipsoid(root, "PilotBuckle", 0.045, Vector3(1.1, 0.9, 0.4), Vector3(0.0, -0.12, -0.32), brass)
	_add_cylinder(root, "PilotShorts", 0.30, 0.22, Vector3(0.0, -0.26, 0.0), olive)
	_add_ellipsoid(root, "PilotWingBadge", 0.055, Vector3(1.4, 0.8, 0.3), Vector3(-0.12, 0.12, _front_z(-0.12, body_radius) - 0.004), brass)

	var cap := _add_ellipsoid(head, "PilotCap", 0.30, Vector3(1.02, 0.60, 1.0), Vector3(0.0, 0.21, 0.06), leather)
	cap.rotation.x = -0.05
	for side in [-1.0, 1.0]:
		var suffix := _side_suffix(side)
		var flap := _add_ellipsoid(head, "PilotEarFlap_" + suffix, 0.095, Vector3(0.55, 1.2, 0.95), Vector3(side * 0.285, 0.115, 0.05), leather_light)
		flap.rotation.z = -side * 0.12
		_add_ellipsoid(head, "GoggleRim_" + suffix, 0.072, Vector3(1.1, 0.95, 0.45), Vector3(side * 0.10, 0.25, -0.262), brass)
		_add_ellipsoid(head, "GoggleLens_" + suffix, 0.052, Vector3(1.02, 0.86, 0.35), Vector3(side * 0.10, 0.25, -0.282), lens)
	_add_capsule(head, "GoggleBridge", 0.017, 0.12, Vector3(0.0, 0.25, -0.27), brass, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	var strap := _add_torus(head, "GoggleStrap", 0.30, 0.36, Vector3(0.0, 0.245, 0.03), leather_light)
	strap.scale = Vector3(1.0, 1.0, 0.92)
	_add_tusks(head, ivory)


## Ghost-Ops Troll: black tactical vest, utility belt, cargo shorts, chest
## radio, black balaclava hood and a skull-print lower-face mask.
static func _add_ghost_gear(root: Node3D, head: Node3D) -> void:
	var body_radius := TROLL_BODY_RADIUS
	var black := _material(Color("#14171A"), 0.10, 0.70)
	var vest_dark := _material(Color("#2B3033"), 0.12, 0.66)
	var cargo := _material(Color("#202426"), 0.04, 0.82)
	var bone := _material(Color("#F2F0E6"), 0.0, 0.50)
	var ivory := _material(Color("#F4EBD0"), 0.0, 0.45)
	var accent := _glow_material(Color("#35F4FF"), 1.2)

	for index in range(3):
		var pouch_x := (float(index) - 1.0) * 0.11
		_add_ellipsoid(root, "VestPouch_%d" % index, 0.05, Vector3(1.3, 1.0, 0.55), Vector3(pouch_x, -0.03, _front_z(pouch_x, body_radius) - 0.012), vest_dark)
	_add_ellipsoid(root, "VestSkullPatch", 0.065, Vector3(1.0, 1.1, 0.3), Vector3(0.0, 0.14, _front_z(0.0, body_radius) - 0.005), bone)
	for side in [-1.0, 1.0]:
		_add_ellipsoid(root, "VestSkullEye_" + _side_suffix(side), 0.015, Vector3(1.0, 1.2, 0.4), Vector3(side * 0.025, 0.155, _front_z(0.025, body_radius) - 0.018), black)
	_add_capsule(root, "ShoulderRadio", 0.03, 0.14, Vector3(0.16, 0.16, _front_z(0.16, body_radius) - 0.012), vest_dark)
	_add_capsule(root, "RadioAntenna", 0.007, 0.16, Vector3(0.16, 0.30, _front_z(0.16, body_radius) - 0.012), black)
	_add_ellipsoid(root, "RadioLight", 0.011, Vector3.ONE, Vector3(0.16, 0.39, _front_z(0.16, body_radius) - 0.012), accent)
	_add_torus(root, "UtilityBelt", 0.26, 0.35, Vector3(0.0, -0.12, 0.0), black)
	_add_cylinder(root, "CargoShorts", 0.30, 0.22, Vector3(0.0, -0.26, 0.0), cargo)
	for side in [-1.0, 1.0]:
		var pocket_x: float = side * 0.20
		_add_ellipsoid(root, "CargoPocket_" + _side_suffix(side), 0.07, Vector3(1.0, 1.1, 0.4), Vector3(pocket_x, -0.26, _front_z(pocket_x, 0.30) - 0.008), vest_dark)
	_add_torus(root, "GhostNeckGaiter", 0.12, 0.27, Vector3(0.0, 0.38, 0.0), black)

	# Balaclava hood wraps the top and back of the head and leaves the face open.
	_add_ellipsoid(head, "GhostBalaclava", 0.31, Vector3(1.05, 1.08, 0.80), Vector3(0.0, 0.02, 0.075), black)
	for side in [-1.0, 1.0]:
		_add_ellipsoid(head, "GhostEyeMask_" + _side_suffix(side), 0.098, Vector3(1.2, 1.3, 0.45), Vector3(side * 0.102, 0.05, -0.243), black)
	# Skull-print lower face: black patch with a row of white teeth.
	_add_ellipsoid(head, "SkullJawPatch", 0.125, Vector3(1.3, 0.80, 0.50), Vector3(0.0, -0.17, -0.235), black)
	for index in range(6):
		var tooth_x := (float(index) - 2.5) * 0.042
		_add_ellipsoid(head, "SkullTooth_%d" % index, 0.022, Vector3(0.8, 1.5, 0.5), Vector3(tooth_x, -0.165, -0.29 + absf(tooth_x) * 0.12), bone)
	_add_tusks(head, ivory)


## Neon Cyan Riot Troll: black riot armor with glowing cyan trim, riot helmet
## with a translucent visor, shoulder armor and a shield carried on the left.
static func _add_riot_gear(root: Node3D, head: Node3D) -> void:
	var armor := _material(Color("#2A2F36"), 0.45, 0.38)
	var armor_light := _material(Color("#3A4048"), 0.45, 0.36)
	var black := _material(Color("#14171A"), 0.20, 0.55)
	var glow := _glow_material(Color("#35F4FF"), 1.7)
	var visor := _glass_material(Color("#3CC8E8"), 0.34)
	var shield_glass := _glass_material(Color("#3CC8E8"), 0.45)
	var ivory := _material(Color("#F4EBD0"), 0.0, 0.45)

	_add_ellipsoid(root, "RiotChestPlate", 0.21, Vector3(1.05, 0.85, 0.34), Vector3(0.0, 0.10, -0.255), armor)
	_add_ellipsoid(root, "RiotChestStripe", 0.16, Vector3(1.0, 0.06, 0.18), Vector3(0.0, 0.17, -0.325), glow)
	for side in [-1.0, 1.0]:
		var pauldron := _add_ellipsoid(root, "RiotShoulderArmor_" + _side_suffix(side), 0.14, Vector3(1.0, 0.70, 1.0), Vector3(side * TROLL_SHOULDER_X, 0.27, 0.0), armor)
		pauldron.rotation.z = -side * 0.35
		_add_ellipsoid(root, "RiotPauldronGlow_" + _side_suffix(side), 0.045, Vector3(1.3, 0.35, 0.8), Vector3(side * (TROLL_SHOULDER_X + 0.03), 0.34, -0.02), glow)
	_add_torus(root, "RiotNeckGuard", 0.12, 0.28, Vector3(0.0, 0.37, 0.0), black)
	_add_torus(root, "RiotBelt", 0.26, 0.35, Vector3(0.0, -0.12, 0.0), black)
	_add_ellipsoid(root, "RiotBeltBuckle", 0.05, Vector3(1.2, 0.9, 0.4), Vector3(0.0, -0.12, -0.32), glow)
	_add_cylinder(root, "RiotHipGuard", 0.30, 0.22, Vector3(0.0, -0.26, 0.0), armor)

	# Riot shield on the character's left side; cosmetic only, no collision.
	_add_ellipsoid(root, "RiotShield", 0.40, Vector3(0.62, 1.0, 0.12), Vector3(-0.62, -0.02, -0.20), armor)
	var rim := _add_torus(root, "RiotShieldRim", 0.37, 0.41, Vector3(-0.62, -0.02, -0.225), glow, Vector3(deg_to_rad(90.0), 0.0, 0.0))
	rim.scale = Vector3(0.62, 1.0, 1.0)
	_add_ellipsoid(root, "RiotShieldWindow", 0.14, Vector3(1.2, 0.9, 0.2), Vector3(-0.62, 0.16, -0.24), shield_glass)
	_add_ellipsoid(root, "RiotShieldEmblem", 0.07, Vector3(1.0, 1.0, 0.25), Vector3(-0.62, -0.22, -0.24), glow)

	# Riot helmet: dome with cheek guards and a translucent visor over the eyes.
	_add_ellipsoid(head, "RiotHelmet", 0.33, Vector3(1.04, 0.70, 1.02), Vector3(0.0, 0.24, 0.04), armor)
	_add_ellipsoid(head, "RiotHelmetCrest", 0.07, Vector3(0.45, 0.55, 2.6), Vector3(0.0, 0.43, 0.03), glow)
	for side in [-1.0, 1.0]:
		_add_ellipsoid(head, "RiotCheekGuard_" + _side_suffix(side), 0.085, Vector3(0.55, 1.2, 0.95), Vector3(side * 0.305, 0.10, 0.02), armor_light)
	_add_ellipsoid(head, "RiotVisor", 0.27, Vector3(1.0, 0.62, 0.35), Vector3(0.0, 0.085, -0.215), visor)
	_add_tusks(head, ivory)


static func _add_tusks(head: Node3D, material: Material) -> void:
	for side in [-1.0, 1.0]:
		var tusk := _add_ellipsoid(head, "TrollTusk_" + _side_suffix(side), 0.03, Vector3(0.62, 2.1, 0.62), Vector3(side * 0.078, -0.14, -0.285), material)
		tusk.rotation = Vector3(-0.25, 0.0, -side * 0.18)


static func _side_suffix(side: float) -> String:
	return "L" if side < 0.0 else "R"


## Z of the body-capsule surface at a given x, so gear sits on the torso.
static func _front_z(x: float, radius: float = 0.38) -> float:
	return -sqrt(maxf(radius * radius - x * x, 0.0))


# ---------------------------------------------------------------------------
# Mesh and material helpers
# ---------------------------------------------------------------------------

static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.0, 0.30)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func _glass_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := _material(Color(color.r, color.g, color.b, alpha), 0.10, 0.12)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func _add_ellipsoid(parent: Node3D, node_name: String, radius: float, scale_value: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	instance.mesh = mesh
	instance.scale = scale_value
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _add_capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation_value
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _add_torus(parent: Node3D, node_name: String, inner_radius: float, outer_radius: float, position: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 12
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation_value
	instance.material_override = material
	parent.add_child(instance)
	return instance
