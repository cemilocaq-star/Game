extends SceneTree
## Netcode helpers: snapshot interpolation, lag-compensated hit test, rewind clamp and reconciliation.

const NET_SYNC := preload("res://scripts/net_sync.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _near(a: Vector3, b: Vector3, tolerance: float = 0.01) -> bool:
	return a.distance_to(b) <= tolerance


func _run() -> void:
	_test_interpolation()
	_test_history_and_rewind()
	_test_ray_capsule()
	_test_reconcile()
	if failures.is_empty():
		print("PASS: snapshot interpolation, position history, lag-compensation hit test and reconciliation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_interpolation() -> void:
	var buffer = NET_SYNC.SnapshotBuffer.new()
	_check(not bool(buffer.sample(100).valid), "empty buffer has nothing to sample")
	buffer.push(1000, Vector3(0, 0, 0), 0.0)
	buffer.push(1100, Vector3(10, 0, 0), 1.0)
	buffer.push(1200, Vector3(20, 0, 0), 2.0)
	var mid: Dictionary = buffer.sample(1050)
	_check(_near(mid.position, Vector3(5, 0, 0)), "interpolates halfway between two snapshots")
	_check(absf(float(mid.yaw) - 0.5) < 0.001, "interpolates yaw")
	_check(not bool(mid.extrapolated), "inside the buffer is not extrapolation")
	var late: Dictionary = buffer.sample(1250)
	_check(bool(late.extrapolated) and _near(late.position, Vector3(25, 0, 0)), "late snapshot extrapolates briefly along the last velocity")
	var very_late: Dictionary = buffer.sample(5000)
	_check(_near(very_late.position, Vector3(30, 0, 0)), "extrapolation is capped at MAX_EXTRAPOLATION_MS")
	_check(_near(buffer.sample(500).position, Vector3(0, 0, 0)), "before the first snapshot holds the first position")
	buffer.push(1150, Vector3(99, 0, 0), 0.0)
	_check(buffer.size() == 3, "out-of-order snapshots are ignored")
	buffer.push(1300, Vector3(200, 0, 0), 0.0)
	_check(buffer.size() == 1, "a teleport (respawn) clears the buffer so the player does not glide")
	var wrap = NET_SYNC.SnapshotBuffer.new()
	wrap.push(0, Vector3.ZERO, 3.0)
	wrap.push(100, Vector3.ZERO, -3.0)
	var wrapped: float = float(wrap.sample(50).yaw)
	_check(absf(wrapped) > 3.0, "yaw interpolates the short way around")


func _test_history_and_rewind() -> void:
	var history = NET_SYNC.PositionHistory.new()
	_check(history.position_at(10) == null, "empty history returns null")
	for step in range(0, 1500, 50):
		history.record(step, Vector3(float(step) * 0.01, 0, 0))
	_check(history.size() <= 25, "history keeps about one second")
	var at_1000: Variant = history.position_at(1000)
	_check(at_1000 is Vector3 and _near(at_1000, Vector3(10, 0, 0)), "history returns the stored position")
	var at_1025: Variant = history.position_at(1025)
	_check(at_1025 is Vector3 and _near(at_1025, Vector3(10.25, 0, 0)), "history interpolates between samples")
	_check(_near(history.position_at(99999), Vector3(14.5, 0, 0)), "newer than the history clamps to the latest")
	_check(NET_SYNC.rewind_ms(0.0) == NET_SYNC.INTERP_DELAY_MS, "no ping still rewinds by the interpolation delay")
	_check(NET_SYNC.rewind_ms(60.0) == 130, "rewind = half the round trip + interpolation delay")
	_check(NET_SYNC.rewind_ms(2000.0) == NET_SYNC.MAX_REWIND_MS, "a huge ping cannot rewind past the fairness clamp")
	_check(NET_SYNC.clamp_rewind(100000) == NET_SYNC.MAX_REWIND_MS and NET_SYNC.clamp_rewind(-5) == 0, "client-reported delay is clamped")
	_check(NET_SYNC.rewind_ms(NAN) == 0, "a non-finite ping is rejected")


func _test_ray_capsule() -> void:
	var origin := Vector3(0, 1.45, 0)
	var forward := Vector3(0, 0, -1)
	var base := Vector3(0, 0, -10)
	var hit: float = NET_SYNC.ray_capsule_distance(origin, forward, 60.0, base)
	_check(hit > 9.4 and hit < 10.0, "a ray straight at a player hits near the front surface (got %f)" % hit)
	_check(NET_SYNC.ray_capsule_distance(origin, forward, 60.0, Vector3(3, 0, -10)) < 0.0, "a ray far to the side misses")
	_check(NET_SYNC.ray_capsule_distance(origin, forward, 5.0, base) < 0.0, "a target beyond the range is not hit")
	_check(NET_SYNC.ray_capsule_distance(origin, Vector3(0, 0, 1), 60.0, base) < 0.0, "a target behind the shooter is not hit")
	_check(NET_SYNC.ray_capsule_distance(Vector3(0, 3.5, 0), forward, 60.0, base) < 0.0, "a ray above the head misses")
	_check(NET_SYNC.ray_capsule_distance(Vector3(0, 0.05, 0), forward, 60.0, base) >= 0.0, "a ray at the feet hits")
	# Sliding players are lower: a head-height ray passes over them.
	_check(NET_SYNC.ray_capsule_distance(origin, forward, 60.0, base, NET_SYNC.PLAYER_RADIUS, NET_SYNC.PLAYER_HEIGHT_SLIDING) < 0.0, "a ray over a sliding player misses")
	# The lag-compensation case: the enemy has since moved 3 m sideways, the rewound position still hits.
	var moved_now := Vector3(3, 0, -10)
	_check(NET_SYNC.ray_capsule_distance(origin, forward, 60.0, moved_now) < 0.0, "at the current position the shot would miss")
	_check(NET_SYNC.ray_capsule_distance(origin, forward, 60.0, base) >= 0.0, "at the rewound position the shot hits")
	var angled: float = NET_SYNC.ray_capsule_distance(origin, Vector3(0.2, 0.0, -1.0).normalized(), 60.0, Vector3(2.0, 0, -10.0))
	_check(angled > 0.0, "an angled shot at an offset target hits")


func _test_reconcile() -> void:
	var here := Vector3(5, 0, 5)
	var same: Dictionary = NET_SYNC.reconcile(here + Vector3(0.1, 0, 0), here, here)
	_check(str(same.action) == "none", "tiny disagreement is ignored (no rubber-banding)")
	var small: Dictionary = NET_SYNC.reconcile(here + Vector3(1.0, 0, 0), here, here + Vector3(0.0, 0, 2.0))
	_check(str(small.action) == "nudge", "moderate disagreement is nudged")
	_check(small.position.x > 5.0 and small.position.x < 6.0 and is_equal_approx(small.position.z, 7.0), "a nudge moves toward the server without teleporting")
	var big: Dictionary = NET_SYNC.reconcile(here + Vector3(10, 0, 0), here, here)
	_check(str(big.action) == "snap" and _near(big.position, here + Vector3(10, 0, 0)), "large disagreement snaps to the server")
	var dead: Dictionary = NET_SYNC.reconcile(here, here + Vector3(0.2, 0, 0), here + Vector3(0.2, 0, 0), true)
	_check(str(dead.action) == "snap", "a dead player always follows the server")
