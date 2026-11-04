extends Node3D
## A thrown rock in flight. It stops at the first creature, tree trunk, boulder,
## ground or water surface in its path, and ends up as a pickup where it falls.
## - A small animal (a lizard or an insect) is stunned for a moment.
## - A big amphibian struck directly goes for the thrower.
## - A splash draws any amphibian lurking nearby that is not already after the
##   player: it erupts and snaps at the spot, and settles there.
## Thrown guts (items with `splat`) hurt nothing: they make a guts pile where
## they land, or are gone in a splash that lures amphibians just the same.

const GRAVITY := 9.8
const STUN_TIME := 2.5
const SMALL := 0.35   # creatures up to this body radius can be stunned
const STEPS := 3
const WIND_DRAG := 0.3

var id := "stone"
var vel := Vector3.ZERO
var thrower: Node3D = null
var world: Node = null
var _age := 0.0
var _done := false


func setup(item_id: String, from: Vector3, velocity: Vector3, by: Node3D, w: Node) -> Node3D:
	id = item_id
	vel = velocity
	thrower = by
	world = w
	position = from
	top_level = true
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.11
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Items.def(id).get("color", Color(0.55, 0.55, 0.52))
	mesh.material = mat
	mi.mesh = mesh
	add_child(mi)
	return self


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var dt := delta / STEPS
	for i in STEPS:
		var prev := global_position
		vel.y -= GRAVITY * dt
		if world.wind != Vector3.ZERO:
			# Air drag toward the wind's speed bends the arc downwind.
			var flat := Vector3(vel.x, 0, vel.z)
			vel += (world.wind - flat) * WIND_DRAG * dt
		var next := prev + vel * dt
		var c := _creature_on(prev, next)
		if c:
			_hit_creature(c)
			return
		var g: float = world.ground_height(next.x, next.z)
		var water: float = world.water_level()
		if g < water and prev.y >= water and next.y < water:
			splash(world, Vector3(next.x, water, next.z))
			_land(next)
			return
		var hit := _solid_on(prev, next)
		if hit:
			if hit.collider.has_meta("hard"):
				Sfx.play_at("hit", hit.position, -10.0, 0.3)
			else:
				Sfx.play_at("step", hit.position, -6.0, 0.3)
			_land(hit.position + hit.normal * 0.1)
			return
		if next.y <= g:
			Sfx.play_at("step", next, -6.0, 0.3)
			_land(next)
			return
		global_position = next
		rotation += Vector3(7.0, 5.0, 0.0) * dt
	if _age > 6.0:
		_land(global_position)


func _creature_on(a: Vector3, b: Vector3) -> Node3D:
	## The first creature whose body the segment a→b passes through. Buried
	## animals are out of reach: the rock splashes above them instead.
	var best: Node3D = null
	var best_t := INF
	var seg := b - a
	var len2 := maxf(seg.length_squared(), 1e-6)
	for c in Game.creatures:
		if not is_instance_valid(c) or c.dead or c.submerged:
			continue
		var t := clampf((c.hit_center() - a).dot(seg) / len2, 0.0, 1.0)
		var miss: float = (a + seg * t).distance_to(c.hit_center())
		if miss < c.hit_radius + 0.08 and t < best_t:
			best = c
			best_t = t
	return best


func _solid_on(a: Vector3, b: Vector3) -> Dictionary:
	## The ground, a tree trunk or a boulder in the way of a→b ({} if clear).
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	if thrower is CollisionObject3D:
		q.exclude = [thrower.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _hit_creature(c: Node3D) -> void:
	if Items.def(id).get("splat", false):
		Sfx.play_at("splash", c.hit_center(), -8.0, 0.3)
		_land(c.global_position + Vector3(0, 0.5, 0))
		return
	var dmg: float = Items.def(id).get("damage", 4.0) * 0.5
	Sfx.play_at("hit", c.hit_center(), -2.0)
	if c.def.radius <= SMALL:
		c.take_damage(dmg, thrower)
		if not c.dead:
			c.stun(STUN_TIME)
	else:
		c.take_damage(dmg, thrower)
	_land(c.global_position + Vector3(0, 0.5, 0))


static func splash(w: Node, p: Vector3) -> void:
	## Rings on the water, and every amphibian close enough turns on the spot.
	ripple(w, p)
	for c in Game.creatures:
		if is_instance_valid(c) and c.def.behavior in ["ambusher", "lurker"]:
			c.lure(p)


static func ripple(w: Node, p: Vector3) -> void:
	## A splash and rings spreading on the water, luring nothing.
	Sfx.play_at("splash", p, 0.0, 0.2)
	for i in 3:
		var r := Ring.new()
		r.delay = i * 0.18
		w.add_child(r)
		r.global_position = p + Vector3(0, 0.03, 0)


func _land(p: Vector3) -> void:
	_done = true
	if Items.def(id).get("splat", false):
		if world and world.has_method("add_guts") and world.ground_height(p.x, p.z) >= world.water_level() - 0.1:
			world.add_guts(p, 1)
		queue_free()
		return
	if world and world.has_method("spawn_pickup"):
		world.spawn_pickup(id, 1, p, 0.0, false)  # thrown stones are gone after a reload
	queue_free()


class Ring extends MeshInstance3D:
	## An expanding, fading ring on the water.
	var delay := 0.0
	var _t := 0.0

	func _ready() -> void:
		var t := TorusMesh.new()
		t.inner_radius = 0.9
		t.outer_radius = 1.0
		t.rings = 20
		t.ring_segments = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.85, 0.9, 0.8, 0.7)
		t.material = m
		mesh = t
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scale = Vector3.ONE * 0.1
		visible = false

	func _process(delta: float) -> void:
		_t += delta
		var k := (_t - delay) / 1.6
		if k < 0.0:
			return
		if k >= 1.0:
			queue_free()
			return
		visible = true
		scale = Vector3(1, 0.3, 1) * lerpf(0.15, 1.6, k)
		transparency = k
