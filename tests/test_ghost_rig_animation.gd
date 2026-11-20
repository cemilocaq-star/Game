extends SceneTree
## Animation checks on the Ghost-Ops costume rig: ten rigid limb shells bound to a Skeleton3D whose
## bones are driven by the shared locomotion pivots. Every check here is one that the shells allow.
## What they do not allow (no head, torso, hip, spine or hand parts) is listed at the end of the run.

const RIG := preload("res://scripts/character_motion_rig.gd")
const HOLD := preload("res://scripts/weapon_hold.gd")
const VISUALS := preload("res://scripts/character_visuals.gd")

const DT := 1.0 / 60.0
const SETTLE_FRAMES := 120
const SAMPLE_FRAMES := 180
const MAX_STEP_RAD := 0.25 ## largest allowed per-frame bone rotation (15 rad/s at 60 fps)
const BONE_SYNC_TOLERANCE := 0.002 ## radians / metres; the skeleton stores poses at reduced precision
const MAX_TRANSITION_STEP_RAD := 0.35 ## an exponential ease starts with its biggest step; a pop would be 0.5+
const NO_STRETCH := 0.0002 ## limb chain lengths may drift by at most 0.2 mm

## name -> [speed, grounded, sliding, emote]
const STATES := {
	"idle": [0.0, true, false, ""],
	"walk": [3.5, true, false, ""],
	"run": [6.6, true, false, ""],
	"slide": [8.0, true, true, ""],
	"airborne": [5.0, false, false, ""],
	"griddy": [0.0, true, false, "griddy"],
	"goofy": [0.0, true, false, "goofy"],
	"robot": [0.0, true, false, "robot"],
	"wave": [0.0, true, false, "wave"],
	"defeat": [0.0, true, false, "defeat"],
}
const BONES := ["UpperArm_", "Forearm_", "Thigh_", "Shin_"]

var failures: Array[String] = []
var host: Node3D
var rig: Node3D
var skeleton: Skeleton3D
var clock := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _pivots(side: String) -> Dictionary:
	var arm := rig.get_node("ArmPivot_" + side) as Node3D
	var leg := rig.get_node("LegPivot_" + side) as Node3D
	return {"arm": arm, "elbow": arm.get_node("ElbowPivot") as Node3D, "leg": leg, "knee": leg.get_node("KneePivot") as Node3D}


func _bone_origin(bone_name: String) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))).origin


func _shell_box(bone_name: String) -> AABB:
	var socket := skeleton.get_child(skeleton.find_bone(bone_name))
	var box := AABB()
	var first := true
	for mesh in socket.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		var local: AABB = (rig.global_transform.affine_inverse() * mesh_instance.global_transform) * mesh_instance.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


func _glove_in_rig(side: String) -> Vector3:
	var elbow: Node3D = _pivots(side).elbow
	return rig.global_transform.affine_inverse() * (elbow.global_transform * HOLD.GLOVE_LOCAL)


func _shoulder_in_rig(side: String) -> Vector3:
	var arm: Node3D = _pivots(side).arm
	return rig.global_transform.affine_inverse() * arm.global_position


func _step(state: Array, frames: int = 1, hold: Dictionary = {}) -> void:
	for index in range(frames):
		clock += DT
		RIG.animate(rig, clock, float(state[0]), bool(state[1]), bool(state[2]), str(state[3]), DT, hold)


func _bone_rotations() -> Dictionary:
	var rotations := {}
	for side in ["L", "R"]:
		for bone_name in BONES:
			rotations[bone_name + side] = skeleton.get_bone_pose_rotation(skeleton.find_bone(bone_name + side))
	return rotations


func _run() -> void:
	host = Node3D.new()
	root.add_child(host)
	rig = RIG.build(host, Color.WHITE, "outfit_ghost_ops")
	skeleton = rig.get_node("GhostCostumeSkeleton") as Skeleton3D
	_check(skeleton.get_bone_count() == 10, "the Ghost skeleton has its ten limb bones")

	var run_levels := {}
	var rest_foot_low := 0.0
	for state_name in STATES:
		var state: Array = STATES[state_name]
		_step(state, SETTLE_FRAMES)
		var elbow_low := 99.0
		var elbow_high := -99.0
		var knee_low := 99.0
		var knee_high := -99.0
		var arm_low := 99.0
		var arm_high := -99.0
		var worst_gap := 0.0
		var worst_sync := 0.0
		var worst_step := 0.0
		var foot_lowest := 99.0
		var arm_inner := 99.0
		var length_low := {}
		var length_high := {}
		var glove_depth := {"L": 0.0, "R": 0.0}
		var previous := {}
		for frame in range(SAMPLE_FRAMES):
			_step(state)
			for side in ["L", "R"]:
				var pivots := _pivots(side)
				var arm: Node3D = pivots.arm
				var elbow: Node3D = pivots.elbow
				var leg: Node3D = pivots.leg
				var knee: Node3D = pivots.knee
				elbow_low = minf(elbow_low, elbow.rotation.x)
				elbow_high = maxf(elbow_high, elbow.rotation.x)
				knee_low = minf(knee_low, knee.rotation.x)
				knee_high = maxf(knee_high, knee.rotation.x)
				arm_low = minf(arm_low, arm.rotation.x)
				arm_high = maxf(arm_high, arm.rotation.x)
				# Bones follow the pivots exactly and joints stay closed.
				worst_gap = maxf(worst_gap, _bone_origin("Forearm_" + side).distance_to(elbow.global_position))
				worst_gap = maxf(worst_gap, _bone_origin("Shin_" + side).distance_to(knee.global_position))
				for pair in [["UpperArm_", arm], ["Forearm_", elbow], ["Thigh_", leg], ["Shin_", knee]]:
					var bone := skeleton.find_bone(str(pair[0]) + side)
					var driver: Node3D = pair[1]
					worst_sync = maxf(worst_sync, skeleton.get_bone_pose_position(bone).distance_to(driver.position))
					worst_sync = maxf(worst_sync, skeleton.get_bone_pose_rotation(bone).angle_to(driver.quaternion))
				# Limbs never stretch: shoulder -> elbow and hip -> knee stay the same length.
				for key in ["arm_" + side, "leg_" + side]:
					var length := 0.0
					if key.begins_with("arm"):
						length = arm.global_position.distance_to(elbow.global_position)
					else:
						length = leg.global_position.distance_to(knee.global_position)
					length_low[key] = minf(float(length_low.get(key, 99.0)), length)
					length_high[key] = maxf(float(length_high.get(key, -99.0)), length)
				foot_lowest = minf(foot_lowest, _shell_box("Foot_" + side).position.y)
				for part in ["UpperArm_", "Forearm_"]:
					var box := _shell_box(part + side)
					var inner := 0.0 if (box.position.x <= 0.0 and box.end.x >= 0.0) else minf(absf(box.position.x), absf(box.end.x))
					arm_inner = minf(arm_inner, inner)
				glove_depth[side] = float(glove_depth[side]) + (_glove_in_rig(side).z - _shoulder_in_rig(side).z) / float(SAMPLE_FRAMES)
				for bone_name in BONES:
					var rotation_now := skeleton.get_bone_pose_rotation(skeleton.find_bone(bone_name + side))
					if previous.has(bone_name + side):
						worst_step = maxf(worst_step, (previous[bone_name + side] as Quaternion).angle_to(rotation_now))
					previous[bone_name + side] = rotation_now
		_check(worst_gap < 0.001, "%s: joints stay closed (worst gap %.5f m)" % [state_name, worst_gap])
		_check(worst_sync < BONE_SYNC_TOLERANCE, "%s: every bone follows its locomotion pivot (worst %.6f)" % [state_name, worst_sync])
		for key in length_low:
			_check(float(length_high[key]) - float(length_low[key]) < NO_STRETCH, "%s: %s does not stretch (%.6f m)" % [state_name, key, float(length_high[key]) - float(length_low[key])])
		_check(elbow_low >= HOLD.ELBOW_LIMITS.x - 0.0001 and elbow_high <= HOLD.ELBOW_LIMITS.y, "%s: the elbow never bends backwards (%.2f..%.2f rad)" % [state_name, elbow_low, elbow_high])
		_check(knee_high <= 0.0001 and knee_low > -2.0, "%s: the knee only bends backwards (%.2f..%.2f rad)" % [state_name, knee_low, knee_high])
		_check(arm_low >= HOLD.ARM_X_LIMITS.x - 0.0001 and arm_high <= HOLD.ARM_X_LIMITS.y, "%s: the shoulder stays inside its range (%.2f..%.2f rad)" % [state_name, arm_low, arm_high])
		_check(worst_step < MAX_STEP_RAD, "%s: no bone snaps between frames (worst %.3f rad/frame)" % [state_name, worst_step])
		_check(arm_inner > 0.2, "%s: arm shells stay outside the torso (nearest %.3f m from the midline)" % [state_name, arm_inner])
		_check(foot_lowest > -1.0, "%s: foot shells do not sink into the floor (lowest %.3f, ground line -0.90)" % [state_name, foot_lowest])
		if state_name == "idle":
			rest_foot_low = foot_lowest
		if state_name in ["griddy", "goofy", "robot", "wave"]:
			var front: float = minf(float(glove_depth.L), float(glove_depth.R))
			_check(front < -0.05, "%s: the hands work in front of the body, not behind it (mean glove depth %.2f m, front is negative)" % [state_name, front])
		run_levels[state_name] = {"foot": foot_lowest, "inner": arm_inner}
	_check(absf(rest_foot_low + 0.9) < 0.04, "at rest the foot shells stand on the ground line within 4 cm (%.3f)" % rest_foot_low)

	_test_symmetry_and_loop()
	_test_transitions()
	_test_weapon_hold()
	_test_abuse()
	_report_limits()

	if failures.is_empty():
		print("PASS: Ghost rig animation (10 states, joints, limits, symmetry, loop, transitions, weapon hold, abuse)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


## Running: arms and legs swing in opposition, left and right have the same amplitude, and the cycle
## repeats exactly after one stride period.
func _test_symmetry_and_loop() -> void:
	var run: Array = STATES.run
	_step(run, SETTLE_FRAMES)
	var peaks := {"arm_L": 0.0, "arm_R": 0.0, "leg_L": 0.0, "leg_R": 0.0}
	var opposed := true
	for frame in range(SAMPLE_FRAMES):
		_step(run)
		var left: Dictionary = _pivots("L")
		var right: Dictionary = _pivots("R")
		var arm_l: float = (left.arm as Node3D).rotation.x
		var arm_r: float = (right.arm as Node3D).rotation.x
		var leg_l: float = (left.leg as Node3D).rotation.x
		var leg_r: float = (right.leg as Node3D).rotation.x
		peaks.arm_L = maxf(peaks.arm_L, absf(arm_l))
		peaks.arm_R = maxf(peaks.arm_R, absf(arm_r))
		peaks.leg_L = maxf(peaks.leg_L, absf(leg_l))
		peaks.leg_R = maxf(peaks.leg_R, absf(leg_r))
		if arm_l * arm_r > 0.0005 or leg_l * leg_r > 0.0005:
			opposed = false
		var arm_vs_leg_same_side: float = arm_l * leg_l
		_check(arm_vs_leg_same_side <= 0.0005, "a running arm swings against the leg on its own side")
	_check(opposed, "left and right limbs are always in opposition while running")
	_check(absf(peaks.arm_L - peaks.arm_R) < 0.05 * maxf(peaks.arm_L, peaks.arm_R), "both arms swing the same distance (%.3f / %.3f)" % [peaks.arm_L, peaks.arm_R])
	_check(absf(peaks.leg_L - peaks.leg_R) < 0.05 * maxf(peaks.leg_L, peaks.leg_R), "both legs swing the same distance (%.3f / %.3f)" % [peaks.leg_L, peaks.leg_R])
	# One stride period later the bones are back where they were.
	var period := TAU / lerpf(7.2, 12.4, 1.0)
	var before := _bone_rotations()
	var frames := int(round(period / DT))
	var drift_time := float(frames) * DT - period
	_step(run, frames)
	var after := _bone_rotations()
	var worst := 0.0
	for key in before:
		worst = maxf(worst, (before[key] as Quaternion).angle_to(after[key]))
	# The 60 Hz grid cannot hit the period exactly; allow the angle the limb covers in the leftover time.
	_check(worst < 0.04 + absf(drift_time) * 12.0, "the run cycle repeats after one stride period (worst %.4f rad)" % worst)


## Going from one state to the next (run -> slide -> air -> ...) moves bones smoothly, never in a jump.
func _test_transitions() -> void:
	var order := ["run", "slide", "airborne", "run", "griddy", "idle", "wave", "goofy", "robot", "defeat", "walk"]
	var previous := _bone_rotations()
	var worst := 0.0
	var worst_at := ""
	var worst_bob := 0.0
	for state_name in order:
		var state: Array = STATES[state_name]
		for frame in range(45):
			_step(state)
			var now := _bone_rotations()
			for key in now:
				var step_angle := (previous[key] as Quaternion).angle_to(now[key])
				if step_angle > worst:
					worst = step_angle
					worst_at = "%s %s" % [state_name, key]
			previous = now
			worst_bob = maxf(worst_bob, absf(rig.position.y))
	_check(worst < MAX_TRANSITION_STEP_RAD, "state changes are smooth (worst %.3f rad/frame at %s)" % [worst, worst_at])
	_check(worst_bob < 0.1, "the body bob stays small across state changes (%.3f m)" % worst_bob)


## With a weapon in hand the glove reaches the target and the Ghost shells follow the solved arm.
func _test_weapon_hold() -> void:
	var targets := {"right": Vector3(0.12, 0.02, -0.46), "left": Vector3(-0.16, 0.08, -0.42)}
	var idle: Array = STATES.idle
	_step(idle, SETTLE_FRAMES, targets)
	for side in ["R", "L"]:
		var glove := _glove_in_rig(side)
		var goal: Vector3 = targets.right if side == "R" else targets.left
		_check(glove.distance_to(goal) < 0.02, "%s glove reaches its hold target (off by %.3f m)" % [side, glove.distance_to(goal)])
		var pivots := _pivots(side)
		var elbow_x: float = (pivots.elbow as Node3D).rotation.x
		_check(elbow_x >= HOLD.ELBOW_LIMITS.x - 0.0001 and elbow_x <= HOLD.ELBOW_LIMITS.y, "%s elbow stays inside its range while holding (%.2f)" % [side, elbow_x])
		_check(_bone_origin("Forearm_" + side).distance_to((pivots.elbow as Node3D).global_position) < 0.001, "%s forearm shell stays joined to the elbow while holding" % side)
	# Letting go returns the arms to their normal pose.
	_step(idle, SETTLE_FRAMES)
	_check(absf((_pivots("R").arm as Node3D).rotation.x) < 0.02, "the arm relaxes after the weapon is put away")


## Random speeds, flags, emotes and frame times never produce NaN, infinity or a runaway pose.
func _test_abuse() -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = 20261117
	var emotes := ["", "", "griddy", "goofy", "robot", "wave", "defeat", "unknown_emote"]
	for index in range(600):
		var deltas := [0.0, DT, DT, 0.033, 0.1, 1.0]
		var state := [generator.randf_range(0.0, 14.0), generator.randf() > 0.3, generator.randf() > 0.8, emotes[generator.randi() % emotes.size()]]
		clock += DT
		RIG.animate(rig, clock, float(state[0]), bool(state[1]), bool(state[2]), str(state[3]), float(deltas[generator.randi() % deltas.size()]))
	var finite := true
	var bounded := true
	for side in ["L", "R"]:
		var pivots := _pivots(side)
		for key in ["arm", "elbow", "leg", "knee"]:
			var rotation_value: Vector3 = (pivots[key] as Node3D).rotation
			finite = finite and is_finite(rotation_value.x) and is_finite(rotation_value.y) and is_finite(rotation_value.z)
			bounded = bounded and absf(rotation_value.x) < 3.2
		for bone_name in BONES:
			var origin := _bone_origin(bone_name + side)
			finite = finite and is_finite(origin.x) and is_finite(origin.y) and is_finite(origin.z)
	_check(finite, "poses stay finite under random abuse")
	_check(bounded, "joint angles stay bounded under random abuse")
	_check(is_finite(rig.position.y) and absf(rig.position.y) < 0.2 and absf(rig.rotation.x) < 0.5, "body bob and lean stay bounded under random abuse")


## Prints what the Ghost shells cannot be tested for. Derived from the skeleton, so it updates itself
## when head, torso or hand parts are added.
func _report_limits() -> void:
	var missing := []
	var checks := {
		"head shell (look-at, nod, turn limits against shoulders)": ["Head", "Neck"],
		"torso shell (lean, twist and breathing on a chest plate)": ["Chest", "Torso", "Spine"],
		"hips/pelvis (hip sway, weight shift, foot IK from the pelvis)": ["Hips", "Pelvis"],
		"hand/finger shells (grip closing, finger poses)": ["Hand_L", "Hand_R"],
	}
	for label in checks:
		var present := false
		for candidate in checks[label]:
			if skeleton.find_bone(candidate) != -1:
				present = true
		if not present:
			missing.append(label)
	print("NOTE: Ghost skeleton has %d bones, all limb sections, no skinning weights (rigid shells)." % skeleton.get_bone_count())
	for label in missing:
		print("NOTE: cannot be tested on the Ghost shells (no part exists): " + label)
	print("NOTE: the procedural head (HeadPivot) and torso capsule are animated, but they are not Ghost assets.")
	print("NOTE: rigid shells have no joint deformation, so candy-wrapper / skin-weight tests do not apply; joints are checked as gaps instead.")
