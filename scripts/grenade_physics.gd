class_name GrenadePhysics
extends RefCounted
## Shared grenade flight and bounce model. The server uses it for the authoritative grenade and
## clients use it for the visual, so both bounce, skid and come to rest the same way.
## Fixed substeps keep the result nearly independent of the frame rate.

const GRAVITY := 9.8
## Share of the speed into the surface that is kept after a bounce.
const NORMAL_RESTITUTION := 0.45
## Share of the speed along the surface that is kept (the grenade skids and rolls a little).
const TANGENT_RETENTION := 0.72
## Below this speed after a bounce the grenade comes to rest.
const REST_SPEED := 1.2
const SURFACE_OFFSET := 0.08
const MAX_SUBSTEP := 1.0 / 60.0
const MAX_STEP_SECONDS := 0.25
const MAX_SPEED := 60.0


## Advances one grenade by `delta` seconds. `space` may be null (free flight, no collisions);
## `exclude` lists collision RIDs to ignore, such as the thrower; `collision_mask` picks the
## layers that stop the grenade. Returns
## {"position": Vector3, "velocity": Vector3}.
static func step(position: Vector3, velocity: Vector3, delta: float, space: PhysicsDirectSpaceState3D, exclude: Array = [], collision_mask: int = 0xFFFFFFFF) -> Dictionary:
	var excluded: Array[RID] = []
	for item in exclude:
		if item is RID:
			excluded.append(item)
	var remaining := minf(delta, MAX_STEP_SECONDS)
	while remaining > 0.00001:
		var dt := minf(remaining, MAX_SUBSTEP)
		remaining -= dt
		velocity.y -= GRAVITY * dt
		if velocity.length() > MAX_SPEED:
			velocity = velocity.normalized() * MAX_SPEED
		var next_position := position + velocity * dt
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(position, next_position)
			query.exclude = excluded
			query.collision_mask = collision_mask
			query.collide_with_areas = false
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				next_position = hit.position + hit.normal * SURFACE_OFFSET
				velocity = bounce_velocity(velocity, hit.normal)
		position = next_position
	return {"position": position, "velocity": velocity}


static func bounce_velocity(velocity: Vector3, normal: Vector3) -> Vector3:
	var into_surface := normal * velocity.dot(normal)
	var along_surface := velocity - into_surface
	var bounced := along_surface * TANGENT_RETENTION - into_surface * NORMAL_RESTITUTION
	if bounced.length() < REST_SPEED:
		return Vector3.ZERO
	return bounced
