extends RefCounted
## Procedural, fictional first-person arcade weapon silhouettes.
## These are deliberately stylized props, not real-world firearm replicas.

static func _material(color: Color, glow: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.metallic = 0.48
	material.roughness = 0.3
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return material

static func _part(parent: Node3D, node_name: String, mesh: Mesh, position: Vector3, color: Color, glow: bool = false, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	instance.material_override = _material(color, glow)
	parent.add_child(instance)
	return instance

static func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, node_name, mesh, position, color, glow)

static func _orb(parent: Node3D, node_name: String, radius: float, position: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _part(parent, node_name, mesh, position, color, glow)

static func _tube(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	return _part(parent, node_name, mesh, position, color, glow, Vector3(deg_to_rad(90.0), 0.0, 0.0))

static func build_weapon(weapon_id: String, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "ArcadeWeapon_" + weapon_id
	var shell := tint.darkened(0.64)
	var trim := tint.lightened(0.18)
	var dark := Color("#17263A")
	match weapon_id:
		"aether":
			_box(root, "AetherCore", Vector3(0.19, 0.18, 0.62), Vector3(0.0, 0.0, -0.10), dark)
			_box(root, "AetherTopRail", Vector3(0.09, 0.05, 0.48), Vector3(0.0, 0.13, -0.08), trim)
			_tube(root, "AetherEmitter", 0.095, 0.16, Vector3(0.0, 0.0, -0.43), tint, true)
			_orb(root, "AetherCell", 0.09, Vector3(0.11, -0.02, 0.05), tint, true)
		"minicore":
			_box(root, "MiniCoreHousing", Vector3(0.29, 0.23, 0.44), Vector3(0.0, 0.0, -0.10), shell)
			for i in range(3):
				_tube(root, "PulseDrum_%d" % i, 0.075, 0.22, Vector3((float(i) - 1.0) * 0.14, 0.02, -0.33), trim, i == 1)
		"hand_cannon":
			_box(root, "NovaChunkyBody", Vector3(0.30, 0.22, 0.40), Vector3(0.0, 0.0, -0.06), shell)
			_orb(root, "NovaPowerGem", 0.12, Vector3(0.0, 0.06, -0.28), tint, true)
			_tube(root, "NovaMuzzle", 0.12, 0.12, Vector3(0.0, 0.0, -0.34), trim, true)
		"pulse_carbine":
			_box(root, "PulseBody", Vector3(0.20, 0.20, 0.67), Vector3(0.0, 0.0, -0.11), shell)
			_box(root, "PulseLeftFin", Vector3(0.055, 0.07, 0.56), Vector3(-0.15, 0.015, -0.16), trim)
			_box(root, "PulseRightFin", Vector3(0.055, 0.07, 0.56), Vector3(0.15, 0.015, -0.16), trim)
			_orb(root, "PulseCore", 0.07, Vector3(0.0, 0.12, -0.18), tint, true)
		"star_piercer":
			_box(root, "PiercerLongPrism", Vector3(0.14, 0.14, 0.90), Vector3(0.0, 0.01, -0.23), shell)
			_tube(root, "PiercerFocusRing", 0.105, 0.045, Vector3(0.0, 0.0, -0.57), tint, true)
			_orb(root, "PiercerCrystal", 0.10, Vector3(0.0, 0.0, -0.68), trim, true)
		"duck_launcher":
			_box(root, "DuckPod", Vector3(0.32, 0.24, 0.40), Vector3(0.0, -0.01, -0.10), shell)
			_orb(root, "DuckHead", 0.17, Vector3(0.0, 0.08, -0.34), tint, true)
			_orb(root, "DuckBeak", 0.07, Vector3(0.0, 0.04, -0.49), Color("#FFC94A"))
		"banana_boomerang":
			_orb(root, "BananaBase", 0.14, Vector3(0.0, 0.0, -0.14), shell)
			_orb(root, "BananaTipA", 0.105, Vector3(-0.11, 0.08, -0.37), tint, true)
			_orb(root, "BananaTipB", 0.105, Vector3(0.11, -0.08, -0.37), tint, true)
			_box(root, "BananaGrip", Vector3(0.12, 0.20, 0.19), Vector3(0.0, -0.16, 0.08), dark)
		"confetti_cannon":
			_tube(root, "ConfettiDrum", 0.17, 0.48, Vector3(0.0, 0.0, -0.18), shell)
			_orb(root, "ConfettiOrb", 0.10, Vector3(0.0, 0.0, -0.45), tint, true)
			for i in range(4):
				_orb(root, "ConfettiBall_%d" % i, 0.035, Vector3((float(i) - 1.5) * 0.10, 0.12, -0.10), Color.from_hsv(float(i) / 4.0, 0.75, 1.0), true)
		"prism_scepter":
			_tube(root, "PrismHandle", 0.045, 0.77, Vector3(0.0, -0.02, -0.04), shell)
			_orb(root, "PrismCrown", 0.17, Vector3(0.0, 0.15, -0.43), tint, true)
			_box(root, "PrismCrossbar", Vector3(0.40, 0.045, 0.08), Vector3(0.0, 0.15, -0.40), trim)
		"vortex_orbiter":
			_orb(root, "VortexHeart", 0.18, Vector3(0.0, 0.0, -0.28), tint, true)
			_tube(root, "VortexRing", 0.20, 0.045, Vector3(0.0, 0.0, -0.28), trim, true)
			for i in range(3):
				var angle := TAU * float(i) / 3.0
				_orb(root, "OrbitingMoon_%d" % i, 0.065, Vector3(cos(angle) * 0.25, sin(angle) * 0.18, -0.28), shell, true)
		"comet_bow":
			_box(root, "CometBowGrip", Vector3(0.11, 0.44, 0.11), Vector3(0.0, 0.0, -0.08), shell)
			_box(root, "CometUpperLimb", Vector3(0.07, 0.50, 0.08), Vector3(0.0, 0.34, -0.08), tint, true)
			_box(root, "CometLowerLimb", Vector3(0.07, 0.50, 0.08), Vector3(0.0, -0.34, -0.08), trim)
			_tube(root, "CometStar", 0.085, 0.32, Vector3(0.0, 0.0, -0.30), tint, true)
		"bubble_burst":
			_orb(root, "BubbleChamber", 0.24, Vector3(0.0, 0.05, -0.22), tint, true)
			_tube(root, "BubbleRim", 0.25, 0.06, Vector3(0.0, 0.05, -0.22), trim, true)
			for i in range(3):
				_orb(root, "Bubble_%d" % i, 0.045, Vector3((float(i) - 1.0) * 0.13, 0.17, -0.18), tint, true)
		"glitch_ray":
			_box(root, "GlitchMainBlock", Vector3(0.23, 0.24, 0.50), Vector3(0.0, 0.0, -0.12), shell)
			for i in range(5):
				_box(root, "GlitchPixel_%d" % i, Vector3(0.08, 0.06, 0.08), Vector3((float(i) - 2.0) * 0.09, 0.16 if i % 2 == 0 else -0.15, -0.35), tint if i % 2 == 0 else trim, true)
		"meteor_mallet":
			_tube(root, "MeteorHandle", 0.065, 0.66, Vector3(0.0, -0.03, 0.0), shell)
			_box(root, "MeteorHead", Vector3(0.44, 0.30, 0.32), Vector3(0.0, 0.20, -0.28), tint, true)
			_orb(root, "MeteorCore", 0.11, Vector3(0.0, 0.21, -0.45), trim, true)
		"frost_wand":
			_tube(root, "FrostHandle", 0.055, 0.72, Vector3(0.0, -0.05, 0.03), shell)
			_orb(root, "FrostOrb", 0.15, Vector3(0.0, 0.27, -0.22), tint, true)
			_box(root, "FrostPrismTop", Vector3(0.09, 0.34, 0.09), Vector3(0.0, 0.49, -0.22), trim, true)
		"solar_lance":
			_tube(root, "SolarShaft", 0.05, 0.92, Vector3(0.0, 0.0, -0.06), shell)
			_orb(root, "SolarSun", 0.18, Vector3(0.0, 0.0, -0.54), tint, true)
			_tube(root, "SolarHalo", 0.21, 0.045, Vector3(0.0, 0.0, -0.54), trim, true)
		"slime_slinger":
			_box(root, "SlimeGrip", Vector3(0.17, 0.25, 0.20), Vector3(0.0, -0.12, 0.05), shell)
			_orb(root, "SlimeTank", 0.22, Vector3(0.0, 0.06, -0.19), tint, true)
			_orb(root, "SlimeDrop", 0.09, Vector3(0.12, 0.17, -0.35), trim, true)
		"pixel_storm":
			_box(root, "PixelBase", Vector3(0.24, 0.24, 0.43), Vector3(0.0, 0.0, -0.16), shell)
			for i in range(7):
				var x := float(i % 3) * 0.10 - 0.10
				var y := float(i / 3) * 0.10 - 0.10
				_box(root, "PixelCube_%d" % i, Vector3(0.075, 0.075, 0.075), Vector3(x, y, -0.40), tint if i % 2 == 0 else trim, true)
		"thunder_drum":
			_tube(root, "ThunderDrumShell", 0.21, 0.36, Vector3(0.0, 0.0, -0.17), shell)
			_tube(root, "ThunderDrumFace", 0.17, 0.045, Vector3(0.0, 0.0, -0.38), tint, true)
			for side in [-1.0, 1.0]:
				_orb(root, "ThunderNode_%s" % side, 0.07, Vector3(side * 0.22, 0.10, -0.10), trim, true)
		"moon_disc":
			_tube(root, "MoonDiscBody", 0.28, 0.11, Vector3(0.0, 0.0, -0.20), shell)
			_orb(root, "MoonCenter", 0.11, Vector3(0.0, 0.0, -0.28), tint, true)
			_orb(root, "MoonCrescentA", 0.075, Vector3(-0.20, 0.10, -0.22), trim, true)
			_orb(root, "MoonCrescentB", 0.075, Vector3(0.20, -0.10, -0.22), trim, true)
		"jellyfish_staff":
			_tube(root, "JellyStaff", 0.045, 0.78, Vector3(0.0, -0.02, 0.0), shell)
			_orb(root, "JellyBell", 0.19, Vector3(0.0, 0.30, -0.20), tint, true)
			for i in range(4):
				_box(root, "JellyTentacle_%d" % i, Vector3(0.035, 0.24, 0.035), Vector3((float(i) - 1.5) * 0.09, 0.05, -0.20), trim)
		"portal_popper":
			_box(root, "PortalHandle", Vector3(0.20, 0.23, 0.33), Vector3(0.0, 0.0, 0.02), shell)
			_tube(root, "PortalGate", 0.22, 0.055, Vector3(0.0, 0.0, -0.35), tint, true)
			_orb(root, "PortalCore", 0.105, Vector3(0.0, 0.0, -0.38), trim, true)
		"rubber_chicken":
			_orb(root, "ChickenBody", 0.17, Vector3(0.0, -0.03, -0.17), Color("#F4D76C"))
			_orb(root, "ChickenHead", 0.12, Vector3(0.0, 0.16, -0.30), Color("#F4D76C"))
			_orb(root, "ChickenBeak", 0.055, Vector3(0.0, 0.14, -0.42), Color("#FF8D3D"))
			_box(root, "ChickenHandle", Vector3(0.13, 0.25, 0.15), Vector3(0.0, -0.20, 0.06), shell)
		_:
			_box(root, "FallbackCore", Vector3(0.20, 0.20, 0.42), Vector3(0.0, 0.0, -0.16), shell)
			_orb(root, "FallbackGlow", 0.10, Vector3(0.0, 0.0, -0.40), tint, true)
	return root
