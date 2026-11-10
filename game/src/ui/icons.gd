extends RefCounted
## Draws item icons: rendered from the item meshes (Assets.icon_atlas) once
## those are ready, otherwise from vector shapes, so no texture assets are
## needed.


static func draw_durability(ci: CanvasItem, r: Rect2, left: float) -> void:
	## A durability bar along the bottom of a slot: how much of an item is left
	## (0..1), amber going red as it runs out, over a dark track so an
	## almost-empty one still shows.
	ci.draw_rect(r.grow(1), Color(0, 0, 0, 0.6))
	if left > 0.0:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x * left, r.size.y)), Color(0.85, 0.3, 0.2).lerp(Color(0.95, 0.72, 0.3), left))


static func draw_item(ci: CanvasItem, r: Rect2, id: String) -> void:
	var def := Items.def(id)
	if def.is_empty():
		return
	var cure := Items.cure_of(id)
	if cure != "":
		# A cured food: the food's own icon, with a badge for how it was cured.
		draw_item(ci, r, Items.base_of(id))
		var badge: Color = {"pickled": Color(0.45, 0.75, 0.3), "spirit": Color(0.9, 0.65, 0.25), "salted": Color(0.95, 0.95, 0.9)}[cure]
		var at := r.position + r.size * Vector2(0.8, 0.2)
		ci.draw_circle(at, r.size.x * 0.13, Color(0, 0, 0, 0.6))
		ci.draw_circle(at, r.size.x * 0.1, badge)
		return
	if Assets.icon_atlas and Assets.icon_rects.has(id):
		ci.draw_texture_rect_region(Assets.icon_atlas, r.grow(r.size.x * 0.08), Assets.icon_rects[id])
		return
	var c: Color = def.get("color", Color.GRAY)
	var o := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.5 * 0.8
	var dark := c.darkened(0.45)
	match def.get("shape", ""):
		"stick":
			ci.draw_line(o + Vector2(-s, s * 0.7), o + Vector2(s, -s * 0.7), dark, s * 0.32)
			ci.draw_line(o + Vector2(-s, s * 0.7), o + Vector2(s, -s * 0.7), c, s * 0.2)
			ci.draw_line(o + Vector2(0, 0), o + Vector2(s * 0.3, s * 0.3), c, s * 0.12)
		"spindle":
			ci.draw_line(o + Vector2(-s, s * 0.7), o + Vector2(s, -s * 0.7), c, s * 0.14)
			ci.draw_circle(o + Vector2(-s * 0.45, s * 0.32), s * 0.3, Items.def("spindle_whorl").color)
			ci.draw_circle(o + Vector2(-s * 0.45, s * 0.32), s * 0.07, Color(0.15, 0.1, 0.08))
		"rod", "fishing_rod":
			ci.draw_line(o + Vector2(-s, s * 0.9), o + Vector2(s, -s * 0.9), c, s * 0.14)
			if def.shape == "fishing_rod":
				var line: Color = Items.def("fishing_line").color
				ci.draw_line(o + Vector2(s, -s * 0.9), o + Vector2(s * 0.75, s * 0.5), line, 1.0)
				ci.draw_arc(o + Vector2(s * 0.62, s * 0.5), s * 0.13, 0.0, PI, 6, Items.def("chitin_hook").color, s * 0.08)
		"root":
			_blob(ci, o + Vector2(s * 0.15, 0), s * 0.55, c, hash(id))
			for i in 3:
				ci.draw_line(o + Vector2(-s * 0.25, 0), o + Vector2(-s * 0.9, (i - 1) * s * 0.35), c.darkened(0.25), s * 0.08)
		"fish":
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-s * 0.9, 0), o + Vector2(-s * 0.3, -s * 0.4), o + Vector2(s * 0.5, -s * 0.2),
				o + Vector2(s * 0.5, s * 0.2), o + Vector2(-s * 0.3, s * 0.4)]), c)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.45, 0), o + Vector2(s * 0.95, -s * 0.4), o + Vector2(s * 0.95, s * 0.4)]), dark)
			ci.draw_circle(o + Vector2(-s * 0.55, -s * 0.08), s * 0.07, Color(0.1, 0.1, 0.08))
		"hook":
			ci.draw_line(o + Vector2(s * 0.25, -s * 0.8), o + Vector2(s * 0.25, s * 0.25), c, s * 0.18)
			ci.draw_arc(o + Vector2(-s * 0.1, s * 0.25), s * 0.35, 0.0, PI, 8, c, s * 0.18)
			ci.draw_line(o + Vector2(-s * 0.45, s * 0.25), o + Vector2(-s * 0.3, 0.0), c, s * 0.14)
		"whorl":
			ci.draw_circle(o, s * 0.7, c)
			ci.draw_circle(o, s * 0.15, Color(0.15, 0.1, 0.08))
		"log", "short_log", "firewood":
			# A round seen end on: bark ring round pale wood (a split wedge for firewood).
			var r0 := s * (0.85 if def.shape != "short_log" else 0.7)
			if def.shape == "firewood":
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0, r0), o + Vector2(-r0, -r0 * 0.6), o + Vector2(r0, -r0 * 0.6)]), Color(0.74, 0.62, 0.42))
				ci.draw_line(o + Vector2(-r0, -r0 * 0.6), o + Vector2(r0, -r0 * 0.6), Color(0.36, 0.30, 0.20), s * 0.16)
			else:
				ci.draw_circle(o, r0, Color(0.36, 0.30, 0.20) if id != "log_stripped" else c.darkened(0.2))
				ci.draw_circle(o, r0 * 0.8, Color(0.74, 0.62, 0.42))
				ci.draw_arc(o, r0 * 0.45, 0, TAU, 16, Color(0.6, 0.48, 0.3), 1.5)
		"bark":
			ci.draw_rect(Rect2(o - Vector2(s * 0.9, s * 0.35), Vector2(s * 1.8, s * 0.7)), c)
			for i in 4:
				ci.draw_line(o + Vector2(-s * 0.8, -s * 0.25 + i * s * 0.17), o + Vector2(s * 0.8, -s * 0.2 + i * s * 0.17), dark, 1.5)
		"branch":
			ci.draw_line(o + Vector2(-s, s * 0.6), o + Vector2(s, -s * 0.6), c, s * 0.22)
			ci.draw_line(o + Vector2(-s * 0.1, s * 0.05), o + Vector2(s * 0.2, s * 0.7), c, s * 0.12)
			_leaf(ci, o + Vector2(s * 0.3, s * 0.75), s * 0.35, Color(0.28, 0.48, 0.18))
		"plank":
			ci.draw_rect(Rect2(o - Vector2(s, s * 0.25), Vector2(s * 2, s * 0.5)), c)
			ci.draw_line(o + Vector2(-s * 0.9, 0), o + Vector2(s * 0.9, s * 0.05), c.darkened(0.2), 1.5)
		"rock", "clay", "chitin", "blob", "guts", "lizard", "dragonfly", "salt", "ember":
			_blob(ci, o, s * 0.8, c, hash(id))
		"flint":
			_blob(ci, o, s * 0.8, c, hash(id))
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.1, -s * 0.5), o + Vector2(s * 0.6, -s * 0.1), o + Vector2(s * 0.2, s * 0.1)]), Color(0.8, 0.78, 0.7))
		"fiber", "cord":
			for i in 4:
				var off := (i - 1.5) * s * 0.18
				var pts := PackedVector2Array()
				for k in 9:
					var t := k / 8.0
					pts.append(o + Vector2(-s + t * 2.0 * s, off + sin(t * TAU + i) * s * (0.12 if def.shape == "fiber" else 0.05)))
				ci.draw_polyline(pts, c if i % 2 == 0 else dark, s * (0.08 if def.shape == "fiber" else 0.16))
		"frond":
			_leaf(ci, o, s, c)
		"tinder":
			for i in 5:
				var y := (i - 2) * s * 0.25
				ci.draw_line(o + Vector2(-s * 0.8, y), o + Vector2(s * 0.8, y + s * 0.15), c if i % 2 else dark, s * 0.18)
		"seed":
			ci.draw_circle(o, s * 0.55, dark)
			ci.draw_circle(o, s * 0.45, c)
			ci.draw_circle(o + Vector2(-s * 0.15, -s * 0.15), s * 0.12, c.lightened(0.4))
		"compost":
			_blob(ci, o + Vector2(0, s * 0.2), s * 0.7, c, 8)
			ci.draw_circle(o + Vector2(-s * 0.2, 0), s * 0.15, c.lightened(0.15))
		"fish_trap":
			for i in 4:
				var x := lerpf(-s * 0.7, s * 0.7, i / 3.0)
				ci.draw_arc(o + Vector2(x, 0), s * (0.3 + 0.12 * minf(i, 2)), 0.0, TAU, 12, c, s * 0.08)
			ci.draw_line(o + Vector2(-s * 0.9, 0), o + Vector2(s * 0.9, -s * 0.5), dark, s * 0.08)
			ci.draw_line(o + Vector2(-s * 0.9, 0), o + Vector2(s * 0.9, s * 0.5), dark, s * 0.08)
		"snare":
			ci.draw_line(o + Vector2(-s, s * 0.6), o + Vector2(s * 0.5, -s * 0.5), c, s * 0.16)
			ci.draw_arc(o + Vector2(s * 0.55, s * 0.25), s * 0.35, 0.0, TAU, 12, Items.def("string").color, s * 0.07)
		"basket":
			ci.draw_rect(Rect2(o + Vector2(-s * 0.8, -s * 0.5), Vector2(s * 1.6, s * 1.3)), dark)
			for i in 3:
				ci.draw_rect(Rect2(o + Vector2(-s * 0.75, -s * 0.45 + i * s * 0.42), Vector2(s * 1.5, s * 0.3)), c)
		"bedroll":
			# A rolled-up bag from the side: the roll, its rolled end, two ties.
			ci.draw_rect(Rect2(o + Vector2(-s * 0.9, -s * 0.45), Vector2(s * 1.6, s * 0.9)), c)
			ci.draw_circle(o + Vector2(s * 0.7, 0), s * 0.45, c.darkened(0.15))
			ci.draw_arc(o + Vector2(s * 0.7, 0), s * 0.28, 0.0, TAU, 14, dark, maxf(s * 0.06, 1.0))
			ci.draw_arc(o + Vector2(s * 0.7, 0), s * 0.12, 0.0, TAU, 10, dark, maxf(s * 0.06, 1.0))
			for x in [-s * 0.5, s * 0.15]:
				ci.draw_line(o + Vector2(x, -s * 0.47), o + Vector2(x, s * 0.47), Assets.CORD, maxf(s * 0.12, 1.5))
		"baitbox":
			# An open box seen from the front, meat heaped over the rim.
			var meat: Color = Color(0.42, 0.36, 0.22) if id == "baitbox_rotten" else Items.def("raw_meat").color
			_blob(ci, o + Vector2(-s * 0.2, -s * 0.3), s * 0.45, meat, 7)
			_blob(ci, o + Vector2(s * 0.3, -s * 0.25), s * 0.35, meat.lightened(0.12), 6)
			ci.draw_rect(Rect2(o + Vector2(-s * 0.85, -s * 0.2), Vector2(s * 1.7, s * 1.0)), c)
			ci.draw_rect(Rect2(o + Vector2(-s * 0.85, -s * 0.2), Vector2(s * 1.7, s * 1.0)), dark, false, maxf(s * 0.08, 1.0))
			ci.draw_line(o + Vector2(-s * 0.85, s * 0.3), o + Vector2(s * 0.85, s * 0.3), dark, maxf(s * 0.06, 1.0))
		"sprout", "shoot":
			ci.draw_arc(o + Vector2(0, -s * 0.2), s * 0.4, 0.0, TAU * 0.8, 16, c, s * 0.2)
			ci.draw_line(o + Vector2(s * 0.4, -s * 0.2), o + Vector2(s * 0.3, s * 0.9), c, s * 0.2)
		"grub":
			for i in 5:
				var a := PI * 0.9 + i * 0.35
				ci.draw_circle(o + Vector2(cos(a), sin(a)) * s * 0.55 + Vector2(s * 0.5, 0), s * (0.28 - i * 0.025), c if i % 2 == 0 else c.darkened(0.15))
		"meat":
			ci.draw_line(o + Vector2(s * 0.2, -s * 0.2), o + Vector2(s * 0.8, -s * 0.8), Color(0.92, 0.9, 0.82), s * 0.18)
			_blob(ci, o + Vector2(-s * 0.15, s * 0.15), s * 0.65, c, 7)
		"blade", "spear_head", "axe_head":
			var pts := PackedVector2Array()
			match def.shape:
				"blade": pts = PackedVector2Array([Vector2(-0.2, 0.9), Vector2(0.3, -0.9), Vector2(0.45, 0.1), Vector2(0.1, 0.9)])
				"spear_head": pts = PackedVector2Array([Vector2(0, -1), Vector2(0.4, 0.2), Vector2(0, 0.9), Vector2(-0.4, 0.2)])
				_: pts = PackedVector2Array([Vector2(-0.6, -0.7), Vector2(0.6, -0.7), Vector2(0.7, 0.1), Vector2(0, 0.9), Vector2(-0.7, 0.1)])
			var poly := PackedVector2Array()
			for p in pts:
				poly.append(o + p * s)
			ci.draw_colored_polygon(poly, c)
			poly.append(poly[0])
			ci.draw_polyline(poly, c.lightened(0.35), 1.5)
		"axe":
			ci.draw_line(o + Vector2(-s * 0.6, s), o + Vector2(s * 0.3, -s * 0.6), Color(0.5, 0.38, 0.24), s * 0.18)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -s), o + Vector2(s * 0.8, -s * 0.6), o + Vector2(s * 0.5, -s * 0.05), o + Vector2(s * 0.05, -s * 0.35)]), Color(0.32, 0.32, 0.38))
		"spear":
			ci.draw_line(o + Vector2(-s, s), o + Vector2(s * 0.5, -s * 0.5), Color(0.5, 0.38, 0.24), s * 0.14)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(s, -s), o + Vector2(s * 0.35, -s * 0.6), o + Vector2(s * 0.6, -s * 0.35)]), Color(0.32, 0.32, 0.38))
			ci.draw_line(o + Vector2(s * 0.3, -s * 0.3), o + Vector2(s * 0.55, -s * 0.55), Color(0.65, 0.6, 0.35), s * 0.22)
		"drill":
			ci.draw_arc(o + Vector2(0, s * 0.3), s * 0.8, PI * 1.1, PI * 1.9, 12, c, s * 0.12)
			ci.draw_line(o + Vector2(-s * 0.75, s * 0.05), o + Vector2(s * 0.75, s * 0.05), Color(0.9, 0.85, 0.7), 1.5)
			ci.draw_line(o + Vector2(0, -s * 0.8), o + Vector2(0, s * 0.9), c.darkened(0.2), s * 0.14)
		"fire":
			ci.draw_line(o + Vector2(-s * 0.8, s * 0.8), o + Vector2(s * 0.8, s * 0.5), Color(0.4, 0.28, 0.16), s * 0.2)
			ci.draw_line(o + Vector2(s * 0.8, s * 0.8), o + Vector2(-s * 0.8, s * 0.5), Color(0.35, 0.25, 0.14), s * 0.2)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -s), o + Vector2(s * 0.5, s * 0.1), o + Vector2(0, s * 0.5), o + Vector2(-s * 0.5, s * 0.1)]), Color(1.0, 0.5, 0.1))
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -s * 0.4), o + Vector2(s * 0.25, s * 0.2), o + Vector2(0, s * 0.45), o + Vector2(-s * 0.25, s * 0.2)]), Color(1.0, 0.85, 0.3))
		"pot", "pot_water":
			var body := PackedVector2Array([o + Vector2(-s * 0.45, -s * 0.6), o + Vector2(s * 0.45, -s * 0.6), o + Vector2(s * 0.75, 0),
				o + Vector2(s * 0.5, s * 0.8), o + Vector2(-s * 0.5, s * 0.8), o + Vector2(-s * 0.75, 0)])
			var pot_col := Color(0.7, 0.42, 0.28) if id != "clay_pot" else c
			ci.draw_colored_polygon(body, pot_col)
			if def.shape == "pot_water":
				ci.draw_rect(Rect2(o + Vector2(-s * 0.45, -s * 0.72), Vector2(s * 0.9, s * 0.22)), c)
			ci.draw_line(o + Vector2(-s * 0.55, -s * 0.6), o + Vector2(s * 0.55, -s * 0.6), pot_col.darkened(0.3), s * 0.15)
		"vessel":
			var vc := c.darkened(0.35)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-s * 0.35, -s * 0.75), o + Vector2(s * 0.35, -s * 0.75), o + Vector2(s * 0.8, -s * 0.1),
				o + Vector2(s * 0.6, s * 0.85), o + Vector2(-s * 0.6, s * 0.85), o + Vector2(-s * 0.8, -s * 0.1)]), c)
			if id.begins_with("vessel_sealed"):
				ci.draw_rect(Rect2(o + Vector2(-s * 0.42, -s * 0.92), Vector2(s * 0.84, s * 0.2)), vc)
			else:
				ci.draw_line(o + Vector2(-s * 0.45, -s * 0.75), o + Vector2(s * 0.45, -s * 0.75), vc, s * 0.15)
		"canteen":
			var wood := Color(0.62, 0.47, 0.30)
			ci.draw_arc(o + Vector2(0, -s * 0.15), s * 0.75, PI * 1.1, PI * 1.9, 10, Color(0.66, 0.6, 0.36), 1.5)
			ci.draw_circle(o + Vector2(0, s * 0.25), s * 0.62, wood)
			ci.draw_arc(o + Vector2(0, s * 0.25), s * 0.62, 0, TAU, 16, wood.darkened(0.35), 1.5)
			ci.draw_rect(Rect2(o + Vector2(-s * 0.14, -s * 0.6), Vector2(s * 0.28, s * 0.3)), wood.darkened(0.1))
			ci.draw_rect(Rect2(o + Vector2(-s * 0.12, -s * 0.78), Vector2(s * 0.24, s * 0.2)), c)
		"flask":
			# A round copper body seen flat on, a short neck, a stopper the
			# colour of what is in it, and the cord over the top.
			var cu := Color(0.80, 0.47, 0.24)
			ci.draw_arc(o + Vector2(0, s * 0.05), s * 0.62, PI * 1.15, PI * 1.85, 10, Color(0.66, 0.6, 0.36), 1.5)
			ci.draw_circle(o + Vector2(0, s * 0.25), s * 0.6, cu)
			ci.draw_arc(o + Vector2(0, s * 0.25), s * 0.6, 0, TAU, 16, cu.darkened(0.4), 1.5)
			ci.draw_arc(o + Vector2(-s * 0.15, s * 0.1), s * 0.3, PI * 1.1, PI * 1.5, 6, cu.lightened(0.35), 1.5)
			ci.draw_rect(Rect2(o + Vector2(-s * 0.12, -s * 0.55), Vector2(s * 0.24, s * 0.25)), cu.darkened(0.15))
			ci.draw_rect(Rect2(o + Vector2(-s * 0.13, -s * 0.75), Vector2(s * 0.26, s * 0.2)), c)
		"soup_pot":
			# Three boards leaning together, the pot hanging under them.
			var wood := Color(0.62, 0.50, 0.33)
			ci.draw_line(o + Vector2(0, -s), o + Vector2(-s * 0.95, s), wood, s * 0.12)
			ci.draw_line(o + Vector2(0, -s), o + Vector2(s * 0.95, s), wood, s * 0.12)
			ci.draw_line(o + Vector2(0, -s), o + Vector2(s * 0.1, s * 0.9), wood.darkened(0.2), s * 0.1)
			ci.draw_line(o + Vector2(0, -s), o + Vector2(0, -s * 0.2), Color(0.66, 0.6, 0.36), 1.5)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-s * 0.35, -s * 0.2), o + Vector2(s * 0.35, -s * 0.2), o + Vector2(s * 0.55, s * 0.25),
				o + Vector2(s * 0.35, s * 0.7), o + Vector2(-s * 0.35, s * 0.7), o + Vector2(-s * 0.55, s * 0.25)]), c)
			ci.draw_line(o + Vector2(-s * 0.42, -s * 0.2), o + Vector2(s * 0.42, -s * 0.2), c.darkened(0.3), s * 0.12)
		"paper":
			ci.draw_rect(Rect2(o - Vector2(s * 0.9, s * 0.65), Vector2(s * 1.8, s * 1.3)), c)
			ci.draw_rect(Rect2(o - Vector2(s * 0.9, s * 0.65), Vector2(s * 1.8, s * 1.3)), c.darkened(0.3), false, 1.5)
		"blueprint":
			# A rolled sheet, tied round the middle.
			ci.draw_line(o + Vector2(-s * 0.85, s * 0.45), o + Vector2(s * 0.85, -s * 0.45), c.darkened(0.35), s * 0.62)
			ci.draw_line(o + Vector2(-s * 0.85, s * 0.45), o + Vector2(s * 0.85, -s * 0.45), c, s * 0.5)
			ci.draw_circle(o + Vector2(-s * 0.85, s * 0.45), s * 0.25, c.darkened(0.25))
			ci.draw_circle(o + Vector2(-s * 0.85, s * 0.45), s * 0.08, c.darkened(0.5))
			ci.draw_line(o + Vector2(-s * 0.12, -s * 0.18), o + Vector2(s * 0.12, s * 0.18), Color(0.66, 0.6, 0.36), s * 0.14)
		"pencil_core", "pencil":
			var w := s * (0.12 if def.shape == "pencil_core" else 0.24)
			ci.draw_line(o + Vector2(-s, s * 0.6), o + Vector2(s * 0.75, -s * 0.45), c, w)
			if def.shape == "pencil":
				ci.draw_line(o + Vector2(s * 0.75, -s * 0.45), o + Vector2(s, -s * 0.6), Color(0.24, 0.23, 0.22), w * 0.5)
		"platter", "bowl":
			var flat := 0.3 if def.shape == "platter" else 0.55
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-s, -s * 0.1), o + Vector2(s, -s * 0.1),
				o + Vector2(s * 0.6, s * flat), o + Vector2(-s * 0.6, s * flat)]), c)
			ci.draw_line(o + Vector2(-s, -s * 0.1), o + Vector2(s, -s * 0.1), c.lightened(0.25), s * 0.12)
		"mug", "mug_full":
			ci.draw_rect(Rect2(o - Vector2(s * 0.55, s * 0.6), Vector2(s * 1.1, s * 1.3)), c)
			ci.draw_arc(o + Vector2(s * 0.6, s * 0.05), s * 0.3, -PI * 0.5, PI * 0.5, 8, c, s * 0.15)
			ci.draw_rect(Rect2(o - Vector2(s * 0.55, s * 0.6), Vector2(s * 1.1, s * 0.15)), Color(0.18, 0.1, 0.05) if def.shape == "mug_full" else c.darkened(0.3))
		"papers":
			for i in 3:
				var d := Vector2(i - 1, -i + 1) * s * 0.12
				ci.draw_rect(Rect2(o - Vector2(s * 0.6, s * 0.8) + d, Vector2(s * 1.2, s * 1.6)), c.darkened(0.1 * (2 - i)))
			for i in 4:
				ci.draw_line(o + Vector2(-s * 0.35, -s * 0.3 + i * s * 0.25), o + Vector2(s * 0.45, -s * 0.3 + i * s * 0.25), c.darkened(0.45), 1.0)
		"keycard":
			ci.draw_rect(Rect2(o - Vector2(s * 0.9, s * 0.55), Vector2(s * 1.8, s * 1.1)), c)
			ci.draw_rect(Rect2(o - Vector2(s * 0.9, s * 0.35), Vector2(s * 1.8, s * 0.2)), Color(0.92, 0.92, 0.9))
			ci.draw_rect(Rect2(o + Vector2(-s * 0.7, 0), Vector2(s * 0.45, s * 0.45)), Color(0.85, 0.7, 0.55))
		"pipe":
			ci.draw_rect(Rect2(o + Vector2(-s, -s * 0.25), Vector2(s * 2, s * 0.5)), c)
			ci.draw_rect(Rect2(o + Vector2(-s, -s * 0.25), Vector2(s * 2, s * 0.12)), c.lightened(0.3))
			ci.draw_rect(Rect2(o + Vector2(-s, -s * 0.35), Vector2(s * 0.2, s * 0.7)), dark)
			ci.draw_rect(Rect2(o + Vector2(s * 0.8, -s * 0.35), Vector2(s * 0.2, s * 0.7)), dark)
		"coil", "wire":
			ci.draw_circle(o, s * 0.8, c)
			ci.draw_circle(o, s * 0.3, Color(0.25, 0.25, 0.28))
			for i in 5:
				ci.draw_arc(o, s * (0.4 + i * 0.09), 0, TAU, 20, dark, 1.0)
		"board":
			ci.draw_rect(Rect2(o - Vector2(s * 0.9, s * 0.6), Vector2(s * 1.8, s * 1.2)), c)
			ci.draw_rect(Rect2(o - Vector2(s * 0.3, s * 0.3), Vector2(s * 0.6, s * 0.6)), Color(0.08, 0.08, 0.08))
			for i in 4:
				ci.draw_line(o + Vector2(-s * 0.8, -s * 0.4 + i * s * 0.27), o + Vector2(-s * 0.35, -s * 0.4 + i * s * 0.27), Color(0.85, 0.75, 0.3), 1.5)
		"cell":
			ci.draw_rect(Rect2(o - Vector2(s * 0.45, s * 0.75), Vector2(s * 0.9, s * 1.6)), c)
			ci.draw_rect(Rect2(o - Vector2(s * 0.15, s * 0.95), Vector2(s * 0.3, s * 0.2)), Color(0.8, 0.8, 0.8))
			ci.draw_line(o + Vector2(-s * 0.2, 0), o + Vector2(s * 0.2, 0), Color.WHITE, 2.0)
			ci.draw_line(o + Vector2(0, -s * 0.2), o + Vector2(0, s * 0.2), Color.WHITE, 2.0)
		"segment", "injector":
			ci.draw_rect(Rect2(o + Vector2(-s, -s * 0.2), Vector2(s * 2, s * 0.4)), Color(0.75, 0.77, 0.8))
			ci.draw_rect(Rect2(o - Vector2(s * 0.45, s * 0.6), Vector2(s * 0.9, s * 1.2)), c)
			if def.shape == "injector":
				ci.draw_circle(o, s * 0.25, Color(0.6, 0.9, 1.0))
		"sack":
			var bag := PackedVector2Array([o + Vector2(-s * 0.3, -s * 0.55), o + Vector2(s * 0.3, -s * 0.55), o + Vector2(s * 0.8, s * 0.2),
				o + Vector2(s * 0.6, s * 0.85), o + Vector2(-s * 0.6, s * 0.85), o + Vector2(-s * 0.8, s * 0.2)])
			ci.draw_colored_polygon(bag, c)
			for i in 3:
				ci.draw_line(o + Vector2(-s * 0.6, i * s * 0.25), o + Vector2(s * 0.6, i * s * 0.25 + s * 0.05), dark, 1.0)
			ci.draw_line(o + Vector2(-s * 0.35, -s * 0.6), o + Vector2(s * 0.35, -s * 0.6), dark, s * 0.14)
			ci.draw_arc(o + Vector2(0, -s * 0.7), s * 0.25, PI, TAU, 8, dark, s * 0.08)
		"bandage":
			ci.draw_circle(o + Vector2(-s * 0.25, 0), s * 0.55, c)
			ci.draw_circle(o + Vector2(-s * 0.25, 0), s * 0.2, dark)
			ci.draw_rect(Rect2(o + Vector2(-s * 0.25, s * 0.25), Vector2(s * 1.1, s * 0.3)), c)
			for i in 3:
				ci.draw_arc(o + Vector2(-s * 0.25, 0), s * (0.28 + i * 0.09), 0, TAU, 16, dark, 1.0)
		_:
			_blob(ci, o, s * 0.7, c, 3)


static func _blob(ci: CanvasItem, o: Vector2, s: float, c: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 9.0
		pts.append(o + Vector2(cos(a), sin(a) * 0.8) * s * rng.randf_range(0.8, 1.05))
	ci.draw_colored_polygon(pts, c)
	var hl := PackedVector2Array()
	for p in pts:
		hl.append(o + (p - o) * 0.5 + Vector2(-s * 0.2, -s * 0.2))
	ci.draw_colored_polygon(hl, c.lightened(0.15))


static func _leaf(ci: CanvasItem, o: Vector2, s: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var t := i / 11.0
		pts.append(o + Vector2(-s + t * 2.0 * s, -sin(t * PI) * s * 0.45 - t * s * 0.2))
	for i in 12:
		var t := 1.0 - i / 11.0
		pts.append(o + Vector2(-s + t * 2.0 * s, sin(t * PI) * s * 0.3 - t * s * 0.2))
	ci.draw_colored_polygon(pts, c)
	ci.draw_line(o + Vector2(-s, 0), o + Vector2(s, -s * 0.2), c.darkened(0.4), 1.5)
