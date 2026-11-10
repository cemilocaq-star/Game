extends RefCounted
## Procedural, fictional first-person arcade weapon models.
## These are deliberately stylized props, not real-world firearm replicas.
##
## Every weapon is assembled from a small set of shape helpers (ellipsoids, tapered
## cones, capsules, tori, prisms and boxes) and five material kinds so metal, plastic,
## rubber, glass and energy read differently. Weapons point along -Z with the grip near
## the origin. Node names used by player.gd animation (VortexRing, RotaryArcFrontRing,
## OrbitingMoon_*, *Cell/*Core/*Gem pulses) are part of the contract and must not change.

const METAL := 0
const DARK := 1
const PLASTIC := 2
const GRIP := 3
const GLASS := 4
const GLOW := 5

static func _material(color: Color, kind: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	match kind:
		METAL:
			material.metallic = 0.55
			material.roughness = 0.30
			material.rim_enabled = true
			material.rim = 0.25
		DARK:
			material.metallic = 0.40
			material.roughness = 0.46
		PLASTIC:
			material.metallic = 0.08
			material.roughness = 0.48
			material.rim_enabled = true
			material.rim = 0.30
		GRIP:
			material.metallic = 0.0
			material.roughness = 0.92
		GLASS:
			material.albedo_color = Color(color.r, color.g, color.b, 0.38)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.metallic = 0.10
			material.roughness = 0.06
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 0.45
		GLOW:
			material.metallic = 0.0
			material.roughness = 0.20
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 2.4
	return material

static func _part(parent: Node3D, node_name: String, mesh: Mesh, position: Vector3, color: Color, kind: int, rotation: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	instance.scale = scale_value
	instance.material_override = _material(color, kind)
	parent.add_child(instance)
	return instance

static func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color, kind: int = METAL, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, node_name, mesh, position, color, kind, rotation)

## Streamlined body: a sphere stretched to the given size.
static func _ell(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color, kind: int = PLASTIC, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return _part(parent, node_name, mesh, position, color, kind, rotation, size)

static func _orb(parent: Node3D, node_name: String, radius: float, position: Vector3, color: Color, kind: int = GLOW) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 9
	return _part(parent, node_name, mesh, position, color, kind)

## Cylinder whose axis runs along Z.
static func _tube(parent: Node3D, node_name: String, radius: float, length: float, position: Vector3, color: Color, kind: int = METAL) -> MeshInstance3D:
	return _cone(parent, node_name, radius, radius, length, position, color, kind)

## Tapered cylinder along Z; r_front points toward -Z (the muzzle side).
static func _cone(parent: Node3D, node_name: String, r_front: float, r_back: float, length: float, position: Vector3, color: Color, kind: int = METAL) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_back
	mesh.bottom_radius = r_front
	mesh.height = length
	mesh.radial_segments = 18
	return _part(parent, node_name, mesh, position, color, kind, Vector3(deg_to_rad(90.0), 0.0, 0.0))

## Rounded rod / pill along Z.
static func _caps(parent: Node3D, node_name: String, radius: float, length: float, position: Vector3, color: Color, kind: int = PLASTIC, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0 + 0.002)
	mesh.radial_segments = 16
	mesh.rings = 6
	return _part(parent, node_name, mesh, position, color, kind, Vector3(deg_to_rad(90.0), 0.0, 0.0) + rotation)

## Ring facing Z. radius is the centre-line radius, thickness the tube radius.
static func _ring(parent: Node3D, node_name: String, radius: float, thickness: float, position: Vector3, color: Color, kind: int = METAL, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - thickness, 0.005)
	mesh.outer_radius = radius + thickness
	mesh.rings = 24
	mesh.ring_segments = 8
	return _part(parent, node_name, mesh, position, color, kind, Vector3(deg_to_rad(90.0), 0.0, 0.0) + rotation)

static func _prism(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color, kind: int = METAL, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _part(parent, node_name, mesh, position, color, kind, rotation)

## Empty pivot so player.gd can spin a ring around its own axis through rotation.z.
static func _pivot(parent: Node3D, node_name: String, position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = position
	parent.add_child(pivot)
	return pivot

static func _grip(parent: Node3D, node_name: String, position: Vector3, color: Color, length: float = 0.24, tilt_degrees: float = 14.0) -> void:
	# _caps already turns the capsule onto the Z axis (+90 degrees about X); -90 stands it
	# upright again and the extra negative angle leans the top toward the muzzle.
	_caps(parent, node_name, 0.055, length, position, color, GRIP, Vector3(deg_to_rad(-90.0 - tilt_degrees), 0.0, 0.0))
	_box(parent, node_name + "Guard", Vector3(0.03, 0.035, 0.15), position + Vector3(0.0, 0.115, -0.085), color.darkened(0.25), DARK)

static func build_weapon(weapon_id: String, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "ArcadeWeapon_" + weapon_id
	var body := tint.darkened(0.55)
	var trim := tint.lightened(0.18)
	var light := tint.lightened(0.45)
	var steel := Color("#9AA7B6")
	var gun := Color("#2B3541")
	var ink := Color("#10161F")
	var rubber := Color("#1A1F27")
	match weapon_id:
		"aether":
			_ell(root, "AetherCore", Vector3(0.20, 0.19, 0.66), Vector3(0.0, 0.0, -0.10), body)
			_cone(root, "BarrelShroud", 0.085, 0.115, 0.36, Vector3(0.0, 0.005, -0.28), steel, METAL)
			_box(root, "UpperPowerRail", Vector3(0.07, 0.035, 0.46), Vector3(0.0, 0.125, -0.08), gun, DARK)
			for i in range(4):
				_box(root, "RailTooth_%d" % i, Vector3(0.09, 0.03, 0.035), Vector3(0.0, 0.15, -0.26 + float(i) * 0.1), steel, METAL)
			_tube(root, "AetherEmitter", 0.075, 0.16, Vector3(0.0, 0.0, -0.45), tint, GLOW)
			_ring(root, "MuzzleRing", 0.095, 0.018, Vector3(0.0, 0.0, -0.50), steel, METAL)
			_orb(root, "AetherCell", 0.075, Vector3(0.115, -0.02, 0.05), tint, GLOW)
			_box(root, "AetherWindow", Vector3(0.012, 0.07, 0.24), Vector3(-0.098, 0.015, -0.12), light, GLASS)
			_grip(root, "AetherGrip", Vector3(0.0, -0.17, 0.13), rubber)
		"minicore":
			_ell(root, "MiniCoreHousing", Vector3(0.30, 0.24, 0.44), Vector3(0.0, 0.0, -0.05), body)
			for i in range(6):
				var angle := TAU * float(i) / 6.0
				_tube(root, "PulseDrum_%d" % i, 0.036, 0.34, Vector3(cos(angle) * 0.085, sin(angle) * 0.085, -0.42), steel if i % 2 == 0 else gun, METAL)
			_ring(root, "MiniCoreFrontBand", 0.125, 0.016, Vector3(0.0, 0.0, -0.52), trim, METAL)
			_ring(root, "MiniCoreMidBand", 0.125, 0.016, Vector3(0.0, 0.0, -0.33), steel, METAL)
			_orb(root, "MiniCoreGlow", 0.06, Vector3(0.0, 0.0, -0.585), tint, GLOW)
			_box(root, "MiniCoreAmmoBox", Vector3(0.11, 0.17, 0.20), Vector3(0.20, -0.07, -0.02), gun, DARK)
			_box(root, "MiniCoreCarryBar", Vector3(0.06, 0.04, 0.26), Vector3(0.0, 0.16, -0.05), steel, METAL)
			_grip(root, "MiniCoreGrip", Vector3(0.0, -0.19, 0.12), rubber)
		"hand_cannon":
			_ell(root, "NovaChunkyBody", Vector3(0.30, 0.24, 0.42), Vector3(0.0, 0.0, -0.06), body)
			_cone(root, "NovaBarrel", 0.095, 0.125, 0.24, Vector3(0.0, 0.015, -0.33), steel, METAL)
			_ring(root, "NovaMuzzleRing", 0.115, 0.022, Vector3(0.0, 0.015, -0.46), trim, METAL)
			_tube(root, "NovaMuzzle", 0.075, 0.07, Vector3(0.0, 0.015, -0.47), tint, GLOW)
			_orb(root, "NovaPowerGem", 0.075, Vector3(0.0, 0.135, -0.14), tint, GLOW)
			_prism(root, "NovaTopFin", Vector3(0.06, 0.07, 0.30), Vector3(0.0, 0.13, 0.02), steel, METAL)
			_box(root, "NovaSideGlass", Vector3(0.012, 0.09, 0.20), Vector3(0.152, 0.0, -0.07), light, GLASS)
			_grip(root, "NovaGrip", Vector3(0.0, -0.20, 0.10), rubber)
		"pulse_carbine":
			_ell(root, "PulseBody", Vector3(0.20, 0.19, 0.68), Vector3(0.0, 0.0, -0.11), body)
			_box(root, "PulseLeftFin", Vector3(0.04, 0.075, 0.54), Vector3(-0.135, 0.015, -0.17), trim, PLASTIC)
			_box(root, "PulseRightFin", Vector3(0.04, 0.075, 0.54), Vector3(0.135, 0.015, -0.17), trim, PLASTIC)
			_cone(root, "PulseBarrel", 0.05, 0.065, 0.34, Vector3(0.0, 0.01, -0.52), steel, METAL)
			_ring(root, "PulseBarrelBand", 0.07, 0.014, Vector3(0.0, 0.01, -0.40), gun, DARK)
			_orb(root, "PulseCore", 0.065, Vector3(0.0, 0.12, -0.18), tint, GLOW)
			_box(root, "PulseSightBase", Vector3(0.05, 0.03, 0.22), Vector3(0.0, 0.115, 0.07), gun, DARK)
			_box(root, "PulseStock", Vector3(0.12, 0.16, 0.20), Vector3(0.0, -0.02, 0.34), rubber, GRIP)
			_grip(root, "PulseGrip", Vector3(0.0, -0.17, 0.15), rubber)
		"star_piercer":
			_ell(root, "PiercerLongPrism", Vector3(0.14, 0.14, 0.92), Vector3(0.0, 0.01, -0.23), body)
			_cone(root, "PiercerNeedle", 0.018, 0.06, 0.40, Vector3(0.0, 0.01, -0.64), steel, METAL)
			_ring(root, "PiercerFocusRing", 0.095, 0.014, Vector3(0.0, 0.01, -0.48), tint, GLOW)
			_ring(root, "PiercerFocusRingB", 0.085, 0.012, Vector3(0.0, 0.01, -0.40), trim, METAL)
			_orb(root, "PiercerCrystal", 0.075, Vector3(0.0, 0.01, -0.84), light, GLOW)
			_prism(root, "PiercerWingL", Vector3(0.16, 0.05, 0.36), Vector3(-0.12, 0.0, -0.18), trim, METAL, Vector3(0.0, 0.0, deg_to_rad(90.0)))
			_prism(root, "PiercerWingR", Vector3(0.16, 0.05, 0.36), Vector3(0.12, 0.0, -0.18), trim, METAL, Vector3(0.0, 0.0, deg_to_rad(-90.0)))
			_grip(root, "PiercerGrip", Vector3(0.0, -0.15, 0.13), rubber)
		"duck_launcher":
			_ell(root, "DuckPod", Vector3(0.32, 0.26, 0.44), Vector3(0.0, -0.01, -0.08), Color("#F0C23A"), PLASTIC)
			_orb(root, "DuckHead", 0.165, Vector3(0.0, 0.10, -0.34), Color("#F4CE4B"), PLASTIC)
			_ell(root, "DuckBeak", Vector3(0.20, 0.07, 0.16), Vector3(0.0, 0.07, -0.51), Color("#FF8D3D"), PLASTIC)
			_orb(root, "DuckEyeL", 0.028, Vector3(-0.07, 0.16, -0.46), ink, PLASTIC)
			_orb(root, "DuckEyeR", 0.028, Vector3(0.07, 0.16, -0.46), ink, PLASTIC)
			_orb(root, "DuckEyeGlowL", 0.014, Vector3(-0.07, 0.17, -0.48), tint, GLOW)
			_orb(root, "DuckEyeGlowR", 0.014, Vector3(0.07, 0.17, -0.48), tint, GLOW)
			_ring(root, "DuckCollar", 0.13, 0.02, Vector3(0.0, 0.03, -0.24), steel, METAL)
			_prism(root, "DuckTail", Vector3(0.14, 0.12, 0.10), Vector3(0.0, 0.08, 0.17), Color("#E3AE2D"), PLASTIC, Vector3(deg_to_rad(-90.0), 0.0, 0.0))
			_grip(root, "DuckGrip", Vector3(0.0, -0.18, 0.06), rubber)
		"banana_boomerang":
			_caps(root, "BananaBase", 0.075, 0.34, Vector3(0.0, 0.0, -0.14), Color("#F6DA45"), PLASTIC)
			_caps(root, "BananaArmA", 0.065, 0.30, Vector3(-0.10, 0.06, -0.36), Color("#F6DA45"), PLASTIC, Vector3(0.0, deg_to_rad(28.0), 0.0))
			_caps(root, "BananaArmB", 0.065, 0.30, Vector3(0.10, -0.06, -0.36), Color("#F6DA45"), PLASTIC, Vector3(0.0, deg_to_rad(-28.0), 0.0))
			_orb(root, "BananaTipA", 0.055, Vector3(-0.19, 0.08, -0.50), Color("#6B4A23"), PLASTIC)
			_orb(root, "BananaTipB", 0.055, Vector3(0.19, -0.08, -0.50), Color("#6B4A23"), PLASTIC)
			_ring(root, "BananaGlowBand", 0.08, 0.014, Vector3(0.0, 0.0, -0.22), tint, GLOW)
			_grip(root, "BananaGrip", Vector3(0.0, -0.15, 0.06), rubber)
		"confetti_cannon":
			_tube(root, "ConfettiDrum", 0.16, 0.46, Vector3(0.0, 0.0, -0.18), body, PLASTIC)
			_cone(root, "ConfettiFlare", 0.24, 0.16, 0.20, Vector3(0.0, 0.0, -0.50), steel, METAL)
			_ring(root, "ConfettiRimBand", 0.165, 0.02, Vector3(0.0, 0.0, -0.40), trim, METAL)
			_orb(root, "ConfettiOrb", 0.09, Vector3(0.0, 0.0, -0.47), tint, GLOW)
			for i in range(5):
				_orb(root, "ConfettiBall_%d" % i, 0.032, Vector3((float(i) - 2.0) * 0.075, 0.18, -0.12), Color.from_hsv(float(i) / 5.0, 0.75, 1.0), GLOW)
			_box(root, "ConfettiHopper", Vector3(0.18, 0.06, 0.20), Vector3(0.0, 0.16, -0.12), gun, DARK)
			_grip(root, "ConfettiGrip", Vector3(0.0, -0.20, 0.08), rubber)
		"prism_scepter":
			_tube(root, "PrismHandle", 0.038, 0.78, Vector3(0.0, -0.02, -0.04), gun, METAL)
			_ring(root, "PrismHandleBand", 0.046, 0.012, Vector3(0.0, -0.02, 0.18), trim, METAL)
			_ring(root, "PrismHandleBandB", 0.046, 0.012, Vector3(0.0, -0.02, -0.12), trim, METAL)
			_prism(root, "PrismCrown", Vector3(0.20, 0.24, 0.16), Vector3(0.0, 0.15, -0.43), tint, GLASS, Vector3(0.0, 0.0, deg_to_rad(0.0)))
			_orb(root, "PrismHeart", 0.06, Vector3(0.0, 0.15, -0.43), light, GLOW)
			_prism(root, "PrismCrossbarL", Vector3(0.20, 0.05, 0.07), Vector3(-0.16, 0.15, -0.43), trim, METAL, Vector3(0.0, 0.0, deg_to_rad(90.0)))
			_prism(root, "PrismCrossbarR", Vector3(0.20, 0.05, 0.07), Vector3(0.16, 0.15, -0.43), trim, METAL, Vector3(0.0, 0.0, deg_to_rad(-90.0)))
		"vortex_orbiter":
			_orb(root, "VortexHeart", 0.15, Vector3(0.0, 0.0, -0.28), tint, GLOW)
			_orb(root, "VortexShell", 0.20, Vector3(0.0, 0.0, -0.28), tint, GLASS)
			var vortex_pivot := _pivot(root, "VortexRing", Vector3(0.0, 0.0, -0.28))
			_ring(vortex_pivot, "VortexRingMesh", 0.22, 0.016, Vector3.ZERO, trim, METAL)
			for i in range(3):
				var angle := TAU * float(i) / 3.0
				_orb(root, "OrbitingMoon_%d" % i, 0.062, Vector3(cos(angle) * 0.25, sin(angle) * 0.18, -0.28), steel, METAL)
			_caps(root, "VortexHandle", 0.05, 0.30, Vector3(0.0, -0.10, 0.03), gun, METAL, Vector3(deg_to_rad(-110.0), 0.0, 0.0))
		"comet_bow":
			_caps(root, "CometBowGrip", 0.05, 0.22, Vector3(0.0, 0.0, -0.08), gun, GRIP, Vector3(deg_to_rad(-90.0), 0.0, 0.0))
			_caps(root, "CometUpperLimb", 0.04, 0.46, Vector3(0.0, 0.30, -0.14), tint, PLASTIC, Vector3(deg_to_rad(-90.0 - 18.0), 0.0, 0.0))
			_caps(root, "CometLowerLimb", 0.04, 0.46, Vector3(0.0, -0.30, -0.14), trim, PLASTIC, Vector3(deg_to_rad(-90.0 + 18.0), 0.0, 0.0))
			_orb(root, "CometStar", 0.07, Vector3(0.0, 0.0, -0.36), light, GLOW)
			_tube(root, "CometArrowRail", 0.012, 0.50, Vector3(0.0, 0.03, -0.28), steel, METAL)
			_box(root, "CometStringTop", Vector3(0.008, 0.28, 0.008), Vector3(0.0, 0.15, 0.04), light, GLOW)
			_box(root, "CometStringBottom", Vector3(0.008, 0.28, 0.008), Vector3(0.0, -0.15, 0.04), light, GLOW)
			_ring(root, "CometGripWrap", 0.056, 0.012, Vector3(0.0, 0.0, -0.08), trim, METAL, Vector3(0.0, 0.0, 0.0))
		"bubble_burst":
			_orb(root, "BubbleChamber", 0.23, Vector3(0.0, 0.05, -0.22), tint, GLASS)
			_orb(root, "BubbleCore", 0.10, Vector3(0.0, 0.05, -0.22), light, GLOW)
			_ring(root, "BubbleRim", 0.24, 0.022, Vector3(0.0, 0.05, -0.36), steel, METAL)
			_cone(root, "BubbleNozzle", 0.12, 0.17, 0.14, Vector3(0.0, 0.05, -0.44), trim, METAL)
			for i in range(4):
				_orb(root, "Bubble_%d" % i, 0.04 + float(i) * 0.004, Vector3((float(i) - 1.5) * 0.12, 0.22 + float(i % 2) * 0.03, -0.18), tint, GLASS)
			_box(root, "BubbleMount", Vector3(0.14, 0.08, 0.22), Vector3(0.0, -0.10, -0.05), gun, DARK)
			_grip(root, "BubbleGrip", Vector3(0.0, -0.19, 0.07), rubber)
		"glitch_ray":
			_box(root, "GlitchMainBlock", Vector3(0.23, 0.22, 0.46), Vector3(0.0, 0.0, -0.10), gun, DARK)
			_box(root, "GlitchShellTop", Vector3(0.20, 0.05, 0.40), Vector3(0.0, 0.135, -0.10), body, PLASTIC, Vector3(0.0, 0.0, deg_to_rad(2.0)))
			for i in range(6):
				var x := float(i % 3) * 0.085 - 0.085
				var y := 0.08 if i < 3 else -0.08
				_box(root, "GlitchPixel_%d" % i, Vector3(0.06, 0.06, 0.06), Vector3(x, y, -0.36 - float(i % 2) * 0.05), tint if i % 2 == 0 else trim, GLOW, Vector3(0.0, deg_to_rad(float(i) * 11.0), 0.0))
			_tube(root, "GlitchLens", 0.075, 0.05, Vector3(0.0, 0.0, -0.34), light, GLASS)
			_box(root, "GlitchVent", Vector3(0.012, 0.10, 0.20), Vector3(0.122, 0.0, -0.08), ink, DARK)
			_grip(root, "GlitchGrip", Vector3(0.0, -0.19, 0.08), rubber)
		"meteor_mallet":
			_caps(root, "MeteorHandle", 0.05, 0.62, Vector3(0.0, -0.03, 0.0), gun, GRIP)
			_ring(root, "MeteorHandleBand", 0.055, 0.012, Vector3(0.0, -0.03, 0.22), trim, METAL)
			_ell(root, "MeteorHead", Vector3(0.40, 0.30, 0.34), Vector3(0.0, 0.17, -0.28), Color("#6A4A3A"), PLASTIC, Vector3(0.0, 0.0, deg_to_rad(8.0)))
			_prism(root, "MeteorSpikeA", Vector3(0.10, 0.12, 0.10), Vector3(-0.14, 0.30, -0.28), Color("#8A6A58"), METAL, Vector3(0.0, 0.0, deg_to_rad(18.0)))
			_prism(root, "MeteorSpikeB", Vector3(0.10, 0.12, 0.10), Vector3(0.13, 0.30, -0.28), Color("#8A6A58"), METAL, Vector3(0.0, 0.0, deg_to_rad(-18.0)))
			_orb(root, "MeteorCore", 0.10, Vector3(0.0, 0.17, -0.45), tint, GLOW)
			_ring(root, "MeteorCrackRing", 0.17, 0.014, Vector3(0.0, 0.17, -0.44), trim, GLOW)
		"frost_wand":
			_caps(root, "FrostHandle", 0.04, 0.68, Vector3(0.0, -0.05, 0.03), steel, METAL)
			_ring(root, "FrostGuardRing", 0.07, 0.014, Vector3(0.0, 0.18, -0.20), trim, METAL, Vector3(0.0, 0.0, 0.0))
			_orb(root, "FrostOrb", 0.13, Vector3(0.0, 0.27, -0.22), tint, GLASS)
			_orb(root, "FrostHeart", 0.06, Vector3(0.0, 0.27, -0.22), light, GLOW)
			_prism(root, "FrostPrismTop", Vector3(0.10, 0.28, 0.10), Vector3(0.0, 0.50, -0.22), trim, GLASS)
			_prism(root, "FrostShardL", Vector3(0.07, 0.17, 0.07), Vector3(-0.12, 0.34, -0.22), light, GLASS, Vector3(0.0, 0.0, deg_to_rad(25.0)))
			_prism(root, "FrostShardR", Vector3(0.07, 0.17, 0.07), Vector3(0.12, 0.34, -0.22), light, GLASS, Vector3(0.0, 0.0, deg_to_rad(-25.0)))
		"solar_lance":
			_tube(root, "SolarShaft", 0.04, 0.90, Vector3(0.0, 0.0, -0.06), gun, METAL)
			_ring(root, "SolarShaftBand", 0.048, 0.012, Vector3(0.0, 0.0, 0.18), trim, METAL)
			_cone(root, "SolarTip", 0.012, 0.075, 0.28, Vector3(0.0, 0.0, -0.68), steel, METAL)
			_orb(root, "SolarSun", 0.13, Vector3(0.0, 0.0, -0.50), tint, GLOW)
			_ring(root, "SolarHalo", 0.19, 0.016, Vector3(0.0, 0.0, -0.50), trim, GLOW)
			_ring(root, "SolarHaloB", 0.15, 0.012, Vector3(0.0, 0.0, -0.50), light, METAL, Vector3(deg_to_rad(40.0), 0.0, 0.0))
			_box(root, "SolarGuardL", Vector3(0.05, 0.012, 0.18), Vector3(-0.10, 0.0, -0.30), trim, METAL, Vector3(0.0, deg_to_rad(18.0), 0.0))
			_box(root, "SolarGuardR", Vector3(0.05, 0.012, 0.18), Vector3(0.10, 0.0, -0.30), trim, METAL, Vector3(0.0, deg_to_rad(-18.0), 0.0))
		"slime_slinger":
			_ell(root, "SlimeBody", Vector3(0.20, 0.20, 0.40), Vector3(0.0, -0.02, -0.04), body, PLASTIC)
			_orb(root, "SlimeTank", 0.20, Vector3(0.0, 0.10, -0.19), tint, GLASS)
			_orb(root, "SlimeBlob", 0.11, Vector3(0.0, 0.07, -0.19), tint, GLOW)
			_cone(root, "SlimeNozzle", 0.04, 0.09, 0.22, Vector3(0.0, -0.02, -0.38), steel, METAL)
			_orb(root, "SlimeDrop", 0.05, Vector3(0.0, -0.10, -0.50), tint, GLOW)
			_tube(root, "SlimeHose", 0.018, 0.22, Vector3(0.0, 0.02, -0.28), gun, GRIP)
			_ring(root, "SlimeTankBand", 0.205, 0.012, Vector3(0.0, 0.10, -0.19), steel, METAL, Vector3(deg_to_rad(90.0), 0.0, 0.0))
			_grip(root, "SlimeGrip", Vector3(0.0, -0.17, 0.05), rubber)
		"pixel_storm":
			_box(root, "PixelBase", Vector3(0.23, 0.22, 0.40), Vector3(0.0, 0.0, -0.12), gun, DARK)
			_box(root, "PixelShell", Vector3(0.20, 0.06, 0.34), Vector3(0.0, 0.13, -0.12), body, PLASTIC)
			for i in range(8):
				var x := float(i % 3) * 0.095 - 0.095
				var y := float(i / 3) * 0.095 - 0.095
				_box(root, "PixelCube_%d" % i, Vector3(0.07, 0.07, 0.07), Vector3(x, y, -0.38 - float(i % 2) * 0.04), tint if i % 2 == 0 else trim, GLOW, Vector3(0.0, 0.0, deg_to_rad(float(i) * 9.0)))
			_box(root, "PixelFrameTop", Vector3(0.30, 0.02, 0.02), Vector3(0.0, 0.14, -0.33), steel, METAL)
			_box(root, "PixelFrameBottom", Vector3(0.30, 0.02, 0.02), Vector3(0.0, -0.14, -0.33), steel, METAL)
			_grip(root, "PixelGrip", Vector3(0.0, -0.18, 0.07), rubber)
		"thunder_drum":
			_tube(root, "ThunderDrumShell", 0.20, 0.34, Vector3(0.0, 0.0, -0.17), Color("#7A4A2B"), PLASTIC)
			_ring(root, "ThunderDrumRimFront", 0.205, 0.022, Vector3(0.0, 0.0, -0.34), steel, METAL)
			_ring(root, "ThunderDrumRimBack", 0.205, 0.022, Vector3(0.0, 0.0, 0.0), steel, METAL)
			_tube(root, "ThunderDrumFace", 0.185, 0.02, Vector3(0.0, 0.0, -0.355), tint, GLASS)
			_orb(root, "ThunderSpark", 0.06, Vector3(0.0, 0.0, -0.37), light, GLOW)
			for side in [-1.0, 1.0]:
				_orb(root, "ThunderNode_%s" % side, 0.055, Vector3(side * 0.21, 0.08, -0.12), trim, GLOW)
				_box(root, "ThunderLug_%s" % side, Vector3(0.03, 0.06, 0.08), Vector3(side * 0.205, 0.0, -0.20), steel, METAL)
			_grip(root, "ThunderGrip", Vector3(0.0, -0.22, 0.04), rubber)
		"moon_disc":
			_tube(root, "MoonDiscBody", 0.27, 0.07, Vector3(0.0, 0.0, -0.20), body, PLASTIC)
			_ring(root, "MoonDiscRim", 0.27, 0.03, Vector3(0.0, 0.0, -0.20), steel, METAL)
			_ring(root, "MoonDiscInner", 0.17, 0.016, Vector3(0.0, 0.0, -0.245), trim, GLOW)
			_orb(root, "MoonCenter", 0.10, Vector3(0.0, 0.0, -0.26), tint, GLOW)
			_orb(root, "MoonCrater_A", 0.045, Vector3(-0.17, 0.10, -0.24), body.darkened(0.3), PLASTIC)
			_orb(root, "MoonCrater_B", 0.035, Vector3(0.18, -0.09, -0.24), body.darkened(0.3), PLASTIC)
			_box(root, "MoonDiscHandle", Vector3(0.05, 0.05, 0.20), Vector3(0.0, -0.27, -0.05), gun, DARK)
		"jellyfish_staff":
			_caps(root, "JellyStaff", 0.04, 0.76, Vector3(0.0, -0.02, 0.0), steel, METAL)
			_ell(root, "JellyBell", Vector3(0.38, 0.26, 0.36), Vector3(0.0, 0.30, -0.20), tint, GLASS)
			_orb(root, "JellyBellCore", 0.08, Vector3(0.0, 0.30, -0.20), light, GLOW)
			for i in range(6):
				var angle := TAU * float(i) / 6.0
				_caps(root, "JellyTentacle_%d" % i, 0.014, 0.26, Vector3(cos(angle) * 0.11, 0.10, -0.20 + sin(angle) * 0.11), trim, GLOW, Vector3(deg_to_rad(-90.0 + sin(angle) * 8.0), 0.0, deg_to_rad(cos(angle) * 8.0)))
			_ring(root, "JellyStaffBand", 0.05, 0.012, Vector3(0.0, 0.05, 0.0), trim, METAL)
		"portal_popper":
			_ell(root, "PortalHandle", Vector3(0.20, 0.22, 0.34), Vector3(0.0, 0.0, 0.02), body, PLASTIC)
			_portal_gate(root, tint, trim, light, steel)
			_orb(root, "PortalCore", 0.09, Vector3(0.0, 0.0, -0.38), light, GLOW)
			_cone(root, "PortalEmitterNeck", 0.10, 0.12, 0.14, Vector3(0.0, 0.0, -0.20), steel, METAL)
			_grip(root, "PortalGrip", Vector3(0.0, -0.17, 0.08), rubber)
		"rubber_chicken":
			_ell(root, "ChickenBody", Vector3(0.34, 0.34, 0.40), Vector3(0.0, -0.03, -0.17), Color("#F4D76C"), PLASTIC)
			_orb(root, "ChickenHead", 0.115, Vector3(0.0, 0.17, -0.31), Color("#F4D76C"), PLASTIC)
			_prism(root, "ChickenBeak", Vector3(0.09, 0.07, 0.12), Vector3(0.0, 0.15, -0.44), Color("#FF8D3D"), PLASTIC, Vector3(deg_to_rad(-90.0), 0.0, 0.0))
			_prism(root, "ChickenComb", Vector3(0.05, 0.09, 0.11), Vector3(0.0, 0.30, -0.31), Color("#E5483B"), PLASTIC)
			_orb(root, "ChickenEyeL", 0.022, Vector3(-0.06, 0.20, -0.40), ink, PLASTIC)
			_orb(root, "ChickenEyeR", 0.022, Vector3(0.06, 0.20, -0.40), ink, PLASTIC)
			_prism(root, "ChickenWingL", Vector3(0.20, 0.04, 0.16), Vector3(-0.19, -0.02, -0.16), Color("#E7C85A"), PLASTIC, Vector3(0.0, 0.0, deg_to_rad(90.0)))
			_prism(root, "ChickenWingR", Vector3(0.20, 0.04, 0.16), Vector3(0.19, -0.02, -0.16), Color("#E7C85A"), PLASTIC, Vector3(0.0, 0.0, deg_to_rad(-90.0)))
			_caps(root, "ChickenLegHandle", 0.05, 0.24, Vector3(0.0, -0.21, 0.07), Color("#FF8D3D"), GRIP, Vector3(deg_to_rad(14.0), 0.0, 0.0))
		"ranger_rifle":
			_ell(root, "RangerMainHousing", Vector3(0.23, 0.21, 0.74), Vector3(0.0, 0.0, -0.12), body)
			_box(root, "RangerRearShell", Vector3(0.22, 0.14, 0.30), Vector3(0.0, 0.015, 0.37), rubber, GRIP, Vector3(deg_to_rad(-4.0), 0.0, 0.0))
			_cone(root, "RangerFrontShroud", 0.085, 0.105, 0.36, Vector3(0.0, 0.0, -0.52), steel, METAL)
			_ring(root, "RangerShroudBand", 0.1, 0.012, Vector3(0.0, 0.0, -0.40), gun, DARK)
			for i in range(5):
				_box(root, "RangerRailTooth_%d" % i, Vector3(0.06, 0.025, 0.03), Vector3(0.0, 0.135, -0.30 + float(i) * 0.085), steel, METAL)
			_box(root, "RangerTopSight", Vector3(0.07, 0.07, 0.24), Vector3(0.0, 0.17, -0.17), gun, DARK)
			_tube(root, "RangerSightLens", 0.027, 0.02, Vector3(0.0, 0.17, -0.30), tint, GLOW)
			_box(root, "RangerLowerGrip", Vector3(0.12, 0.20, 0.15), Vector3(0.0, -0.18, 0.09), rubber, GRIP, Vector3(deg_to_rad(14.0), 0.0, 0.0))
			_box(root, "RangerMagazine", Vector3(0.10, 0.20, 0.11), Vector3(0.0, -0.19, -0.14), gun, DARK, Vector3(deg_to_rad(-6.0), 0.0, 0.0))
			_tube(root, "RangerEnergyEmitter", 0.05, 0.12, Vector3(0.0, 0.0, -0.74), tint, GLOW)
			_orb(root, "RangerSideCell", 0.065, Vector3(0.125, 0.015, -0.12), tint, GLOW)
			_box(root, "RangerSidePanel", Vector3(0.025, 0.11, 0.25), Vector3(-0.125, 0.015, -0.20), trim, PLASTIC)
		"heavy_sidearm":
			_ell(root, "SidearmMainShell", Vector3(0.27, 0.21, 0.42), Vector3(0.0, 0.0, -0.08), body)
			_box(root, "SidearmUpperPlate", Vector3(0.20, 0.05, 0.28), Vector3(0.0, 0.125, -0.13), steel, METAL)
			for i in range(3):
				_box(root, "SidearmSlide_%d" % i, Vector3(0.22, 0.015, 0.02), Vector3(0.0, 0.155, -0.04 - float(i) * 0.06), gun, DARK)
			_cone(root, "SidearmBarrel", 0.075, 0.105, 0.22, Vector3(0.0, 0.01, -0.32), steel, METAL)
			_ring(root, "SidearmMuzzleBand", 0.095, 0.014, Vector3(0.0, 0.01, -0.44), trim, METAL)
			_tube(root, "SidearmPulseEmitter", 0.065, 0.06, Vector3(0.0, 0.01, -0.45), tint, GLOW)
			_orb(root, "SidearmChargeGem", 0.07, Vector3(0.0, 0.115, -0.20), tint, GLOW)
			_box(root, "SidearmGripAccent", Vector3(0.03, 0.15, 0.11), Vector3(0.07, -0.18, 0.07), trim, PLASTIC)
			_grip(root, "SidearmGrip", Vector3(0.0, -0.19, 0.07), rubber)
		"longshot":
			_ell(root, "LongshotSpine", Vector3(0.17, 0.17, 0.98), Vector3(0.0, 0.0, -0.25), body)
			_box(root, "LongshotRearPad", Vector3(0.20, 0.18, 0.22), Vector3(0.0, 0.0, 0.31), rubber, GRIP)
			_cone(root, "LongshotFrontShell", 0.075, 0.10, 0.40, Vector3(0.0, 0.0, -0.72), steel, METAL)
			_ring(root, "LongshotMuzzleBand", 0.09, 0.012, Vector3(0.0, 0.0, -0.58), gun, DARK)
			_tube(root, "LongshotScopeBody", 0.06, 0.34, Vector3(0.0, 0.18, -0.24), gun, METAL)
			_cone(root, "LongshotScopeHood", 0.075, 0.062, 0.08, Vector3(0.0, 0.18, -0.45), steel, METAL)
			_tube(root, "LongshotScopeLens", 0.066, 0.02, Vector3(0.0, 0.18, -0.49), tint, GLASS)
			_box(root, "LongshotScopeMountA", Vector3(0.04, 0.06, 0.04), Vector3(0.0, 0.105, -0.13), gun, DARK)
			_box(root, "LongshotScopeMountB", Vector3(0.04, 0.06, 0.04), Vector3(0.0, 0.105, -0.35), gun, DARK)
			_tube(root, "LongshotEnergyLens", 0.065, 0.08, Vector3(0.0, 0.0, -0.96), tint, GLOW)
			_box(root, "LongshotSideRail", Vector3(0.035, 0.05, 0.62), Vector3(0.115, 0.06, -0.28), trim, METAL)
			_orb(root, "LongshotChargeCell", 0.07, Vector3(-0.125, 0.015, -0.12), tint, GLOW)
			_box(root, "LongshotBipodL", Vector3(0.02, 0.18, 0.02), Vector3(-0.07, -0.13, -0.62), gun, DARK, Vector3(0.0, 0.0, deg_to_rad(14.0)))
			_box(root, "LongshotBipodR", Vector3(0.02, 0.18, 0.02), Vector3(0.07, -0.13, -0.62), gun, DARK, Vector3(0.0, 0.0, deg_to_rad(-14.0)))
			_grip(root, "LongshotGrip", Vector3(0.0, -0.17, 0.12), rubber)
		"rotary_arc":
			_ell(root, "RotaryArcHousing", Vector3(0.36, 0.30, 0.42), Vector3(0.0, 0.0, -0.08), body)
			_box(root, "RotaryArcTopGrip", Vector3(0.10, 0.05, 0.26), Vector3(0.0, 0.19, 0.00), steel, METAL)
			_box(root, "RotaryArcCarryPost", Vector3(0.04, 0.10, 0.04), Vector3(0.0, 0.16, -0.08), gun, DARK)
			var arc_pivot := _pivot(root, "RotaryArcFrontRing", Vector3(0.0, 0.0, -0.45))
			_ring(arc_pivot, "RotaryArcFrontRingMesh", 0.20, 0.028, Vector3.ZERO, steel, METAL)
			_ring(arc_pivot, "RotaryArcInnerRing", 0.15, 0.012, Vector3.ZERO, tint, GLOW)
			for i in range(4):
				var angle := TAU * float(i) / 4.0
				var emitter_position := Vector3(cos(angle) * 0.10, sin(angle) * 0.10, -0.50)
				_tube(root, "RotaryArcEmitter_%d" % i, 0.04, 0.34, emitter_position, tint if i == 0 else gun, GLOW if i == 0 else METAL)
			_orb(root, "RotaryArcPowerCore", 0.11, Vector3(0.0, 0.0, -0.14), tint, GLOW)
			_orb(root, "RotaryArcSideCell", 0.075, Vector3(0.20, 0.02, -0.10), trim, GLOW)
			_box(root, "RotaryArcAmmoDrum", Vector3(0.10, 0.20, 0.18), Vector3(-0.21, -0.05, -0.06), gun, DARK)
			_grip(root, "RotaryArcGrip", Vector3(0.0, -0.22, 0.08), rubber)
		_:
			_ell(root, "FallbackCore", Vector3(0.20, 0.20, 0.44), Vector3(0.0, 0.0, -0.16), body)
			_orb(root, "FallbackGlow", 0.09, Vector3(0.0, 0.0, -0.40), tint, GLOW)
	return root

static func _portal_gate(root: Node3D, tint: Color, trim: Color, light: Color, steel: Color) -> void:
	_ring(root, "PortalGate", 0.22, 0.03, Vector3(0.0, 0.0, -0.36), steel, METAL)
	_ring(root, "PortalGateInner", 0.17, 0.014, Vector3(0.0, 0.0, -0.36), tint, GLOW)
	_ring(root, "PortalGateOuter", 0.25, 0.012, Vector3(0.0, 0.0, -0.355), trim, METAL)
	_orb(root, "PortalSwirl", 0.12, Vector3(0.0, 0.0, -0.36), light, GLASS)
