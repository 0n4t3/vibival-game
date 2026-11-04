extends RefCounted
## Builds flat-shaded, vertex-coloured triangle meshes. Each material slot
## ("solid", "foliage", "glow", ...) becomes its own surface; Assets assigns
## the shared material for the slot when the mesh is committed.
##
## Winding: Godot treats clockwise triangles as front faces, which with the
## normal (c - a) x (b - a) means `tri(a, b, c)` faces the side the normal
## points to.

var _surf := {}


func _arrays(slot: String) -> Array:
	if not _surf.has(slot):
		_surf[slot] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
	return _surf[slot]


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, slot := "solid") -> void:
	var s := _arrays(slot)
	var n := (c - a).cross(b - a)
	n = n.normalized() if n.length_squared() > 0.0 else Vector3.UP
	s[0].append(a); s[0].append(b); s[0].append(c)
	s[1].append(n); s[1].append(n); s[1].append(n)
	s[2].append(col); s[2].append(col); s[2].append(col)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, slot := "solid") -> void:
	tri(a, b, c, col, slot)
	tri(a, c, d, col, slot)


static func frame(axis: Vector3) -> Array:
	## Returns [u, v] perpendicular to axis with u x v == -axis, which keeps
	## ring-based shapes wound outward.
	var a := axis.normalized()
	var ref := Vector3.UP if absf(a.y) < 0.95 else Vector3.RIGHT
	var u := a.cross(ref).normalized()
	var v := u.cross(a).normalized()
	return [u, v]


func cylinder(base: Vector3, top: Vector3, r0: float, r1: float, sides: int,
		col: Color, col_top := Color(-1, 0, 0), slot := "solid", caps := true, twist := 0.0) -> void:
	var f := frame(top - base)
	var u: Vector3 = f[0]
	var v: Vector3 = f[1]
	if col_top.r < 0.0:
		col_top = col
	var ring0 := []
	var ring1 := []
	for i in sides:
		var ang := TAU * i / sides + twist
		var d := u * cos(ang) + v * sin(ang)
		ring0.append(base + d * r0)
		ring1.append(top + d * r1)
	for i in sides:
		var j := (i + 1) % sides
		var shade := 0.88 + 0.12 * cos(TAU * i / sides)
		quad(ring0[i], ring0[j], ring1[j], ring1[i], col.lerp(col_top, 0.5) * shade, slot)
	if caps:
		for i in sides:
			var j := (i + 1) % sides
			if r1 > 0.001:
				tri(top, ring1[i], ring1[j], col_top, slot)
			if r0 > 0.001:
				tri(base, ring0[j], ring0[i], col, slot)


func tube(points: Array, radii: Array, sides: int, cols: Array, slot := "solid") -> void:
	## A bent cylinder through `points`; per-segment colours. Each point gets
	## one ring, square to the bend there and carried along from the last one
	## without twisting, so neighbouring segments meet without seams.
	var n := points.size()
	if n < 2:
		return
	var rings := []
	var u := Vector3.ZERO
	for i in n:
		var d: Vector3
		if i == 0:
			d = points[1] - points[0]
		elif i == n - 1:
			d = points[i] - points[i - 1]
		else:
			d = (points[i + 1] - points[i]).normalized() + (points[i] - points[i - 1]).normalized()
			if d.length_squared() < 0.0001:
				d = points[i + 1] - points[i]
		d = d.normalized()
		if i == 0:
			u = frame(d)[0]
		else:
			u = u - d * u.dot(d)
			u = u.normalized() if u.length_squared() > 0.0001 else frame(d)[0]
		var v := u.cross(d)
		var ring := []
		for k in sides:
			var ang := TAU * k / sides
			ring.append(points[i] + (u * cos(ang) + v * sin(ang)) * radii[i])
		rings.append(ring)
	for i in n - 1:
		var col: Color = cols[mini(i, cols.size() - 1)]
		for k in sides:
			var j := (k + 1) % sides
			quad(rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k], col * (0.88 + 0.12 * cos(TAU * k / sides)), slot)
	var first: Color = cols[0]
	var last: Color = cols[mini(n - 2, cols.size() - 1)]
	for k in sides:
		var j := (k + 1) % sides
		tri(points[n - 1], rings[n - 1][k], rings[n - 1][j], last, slot)
		tri(points[0], rings[0][j], rings[0][k], first, slot)


func cone(base: Vector3, tip: Vector3, r: float, sides: int, col: Color, slot := "solid") -> void:
	cylinder(base, tip, r, 0.0, sides, col, col, slot, true)


func box(center: Vector3, size: Vector3, col: Color, basis := Basis(), slot := "solid") -> void:
	var h := size * 0.5
	var p := []
	for i in 8:
		var c := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		p.append(center + basis * c)
	# Faces: +X, -X, +Y, -Y, +Z, -Z (each wound to face outward).
	quad(p[1], p[5], p[7], p[3], col * 0.92, slot)
	quad(p[0], p[2], p[6], p[4], col * 0.92, slot)
	quad(p[2], p[3], p[7], p[6], col, slot)
	quad(p[0], p[4], p[5], p[1], col * 0.7, slot)
	quad(p[4], p[6], p[7], p[5], col * 0.85, slot)
	quad(p[0], p[1], p[3], p[2], col * 0.85, slot)


func blob(center: Vector3, radius: Vector3, rings: int, sides: int, col: Color,
		rng: RandomNumberGenerator = null, jitter := 0.0, slot := "solid") -> void:
	## A low-poly ellipsoid, optionally lumpy (rocks, bodies, seeds).
	rings = maxi(rings, 2)  # one ring is just the two poles: nothing to draw
	var grid := []
	for r in rings + 1:
		var lat := PI * r / rings - PI * 0.5
		var row := []
		for s in sides:
			var lon := TAU * s / sides
			var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var k := 1.0
			if rng and r > 0 and r < rings:
				k += rng.randf_range(-jitter, jitter)
			row.append(center + d * radius * k)
		grid.append(row)
	for r in rings:
		for s in sides:
			var t := (s + 1) % sides
			var shade := lerpf(0.75, 1.0, float(r) / rings)
			quad(grid[r][s], grid[r][t], grid[r + 1][t], grid[r + 1][s], col * shade, slot)


func lathe(profile: Array, sides: int, col: Color, slot := "solid", origin := Vector3.ZERO, shade := true) -> void:
	## Revolves a profile of Vector2(radius, height) points around the Y axis.
	## The surface faces left of the direction of travel: a profile running up
	## the outside faces out, and one coming back down the inside faces in.
	var f := frame(Vector3.UP)
	var u: Vector3 = f[0]
	var v: Vector3 = f[1]
	var rings := []
	for p in profile:
		var ring := []
		for i in sides:
			var ang := TAU * i / sides
			ring.append(origin + (u * cos(ang) + v * sin(ang)) * p.x + Vector3.UP * p.y)
		rings.append(ring)
	for k in rings.size() - 1:
		for i in sides:
			var j := (i + 1) % sides
			var c := col * (0.9 + 0.1 * cos(TAU * i / sides)) if shade else col
			quad(rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i], c, slot)


func leaf(base: Vector3, dir: Vector3, length: float, width: float, droop: float,
		segs: int, col: Color, tip_col := Color(-1, 0, 0), slot := "foliage") -> void:
	## A tapered, drooping strip; rendered double-sided by the foliage slot.
	if tip_col.r < 0.0:
		tip_col = col
	var d := dir.normalized()
	var side := d.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var prev_l := base
	var prev_r := base
	var pos := base
	for i in segs:
		var t := float(i + 1) / segs
		var step := d * (length / segs)
		step.y -= droop * t * (length / segs)
		pos += step
		var w := width * sin(PI * minf(t, 0.98)) * 0.5
		var l := pos - side * w
		var r := pos + side * w
		quad(prev_l, l, r, prev_r, col.lerp(tip_col, t), slot)
		prev_l = l
		prev_r = r


func commit(materials: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for slot in _surf:
		var s: Array = _surf[slot]
		if s[0].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s[0]
		arrays[Mesh.ARRAY_NORMAL] = s[1]
		arrays[Mesh.ARRAY_COLOR] = s[2]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials.get(slot, materials.get("solid")))
	return mesh


func is_empty() -> bool:
	for slot in _surf:
		if not _surf[slot][0].is_empty():
			return false
	return true
