extends Control
## The papers on the breakroom table (lab.gd), read one at a time while the
## stack is "crafted" at the table: a click (or the work button) turns the
## top page over and shows the next. Each page is drawn here, no textures:
## a safety report, a magazine, newspaper cuttings, adverts and a diary. Most
## of them slip in a hint about surviving the swamp.

signal turned

const Icons := preload("res://src/ui/icons.gd")

const ASPECT := 0.72          # a page's width over its height
const PAGES := 9
const NEWSPRINT := Color(0.88, 0.86, 0.79)
const WHITE := Color(0.96, 0.96, 0.94)
const INK := Color(0.1, 0.1, 0.11)
const GREY := Color(0.55, 0.54, 0.5)
const RED := Color(0.75, 0.12, 0.1)
const PENCIL := Color(0.22, 0.24, 0.38)

var page := 0

var _r := Rect2()             # the page on screen
var _s := 1.0                 # pixels to a page unit (a page is 100 units across)
var _font: Font
var _bold: FontVariation
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_bold = FontVariation.new()
	_bold.base_font = _font
	_bold.variation_embolden = 0.9


func show_page(k: int) -> void:
	if k != page:
		page = k
		queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _r.has_point(ev.position):
			turned.emit()


func page_rect() -> Rect2:
	## The page, as big as fits in this control, in the middle of it.
	var h := minf(size.y, size.x / ASPECT)
	var w := h * ASPECT
	return Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))


func _draw() -> void:
	_r = page_rect()
	_s = _r.size.x / 100.0
	_rng.seed = 7 + page
	# A shadow under the page and the rest of the stack peeking out.
	draw_rect(Rect2(_r.position + Vector2(6, 8), _r.size), Color(0, 0, 0, 0.35))
	if page < PAGES - 1:
		draw_rect(Rect2(_r.position + Vector2(3, 4), _r.size), Color(0.8, 0.79, 0.75))
	match page:
		0:
			_safety_report()
		1:
			_magazine()
		2:
			_paper_headline("New hunting strategy emerges",
				"\"Sometimes, when I'm craving some meat, I throw rocks at a small animal to stun it. Once I get my hands on 'em it's easy to rip their guts out and eat them. I keep extra rocks on me, though. They're good at distracting the bigger animals at the petting zoo\" says Pet and Play Manager",
				_hunter)
		3:
			_poster("Tactical Bow Drill!", "Why buy a functional one for less when you can have a tactical one",
				"bow_drill", "67 tools in one, only $99.99 plus tax", Color(0.42, 0.45, 0.28))
		4:
			_paper_headline("Tour guide watches man eaten by alligator",
				"\"Those darn things are really hard to see when they're waiting in the water, had I not pointed them out they wouldn't have even known they were there. Now I wish I hadn't or Jimbob Goober wouldn't have tried to take a selfie with it and gotten eaten.\"",
				_alligator)
		5:
			_paper_headline("Arsonist testifies at Clemency Hearing",
				"\"I was so poor, I couldn't afford a fire starter. I had to keep grabbing embers from one fire and bring them to the next.\"",
				Callable())
		6:
			_poster("Tactical Stone Blade", "Gut animals, cut cordage, and get through TSA metal detectors.",
				"flint_blade", "Only $69! Endorsed by Pet and Play.", Color(0.36, 0.33, 0.3))
		7:
			_paper_headline("Water Treatment Guide",
				"\"You shouldn't just expect to be able to drink any water, people complaining about needing to treat water before they drink it are committing pure slander\" says Monsanto employee, commenting on the water boil order.",
				_stove)
		_:
			_diary()
	# Which page this is, under it.
	var n := "%d / %d" % [page + 1, PAGES]
	draw_string(_font, Vector2(_r.position.x, _r.end.y + 18), n, HORIZONTAL_ALIGNMENT_CENTER, _r.size.x, 14, Color(1, 1, 1, 0.75))


# --- Drawing helpers -------------------------------------------------------------------
# Positions and sizes are in page units: 100 across, 1/ASPECT (about 139) down.

func _p(x: float, y: float) -> Vector2:
	return _r.position + Vector2(x, y) * _s


func _box(x: float, y: float, w: float, h: float, col: Color, filled := true, width := 1.0) -> void:
	draw_rect(Rect2(_p(x, y), Vector2(w, h) * _s), col, filled, width * _s if not filled else -1.0)


func _text(text: String, y: float, size: float, col := INK, bold := false, align := HORIZONTAL_ALIGNMENT_CENTER,
		x := 8.0, w := 84.0) -> float:
	## Wrapped text from the top at y; returns the y under it.
	var f: Font = _bold if bold else _font
	var px := maxi(roundi(size * _s), 6)
	var block := f.get_multiline_string_size(text, align, w * _s, px)
	draw_multiline_string(f, _p(x, y) + Vector2(0, f.get_ascent(px)), text, align, w * _s, px, -1, col)
	return y + block.y / _s


func _line(a: Vector2, b: Vector2, col := INK, width := 0.6) -> void:
	draw_line(_p(a.x, a.y), _p(b.x, b.y), col, maxf(width * _s, 1.0), true)


func _filler(y0: float, y1: float, x := 8.0, w := 84.0) -> void:
	## Grey bars for the rest of a page's small print, too small to read.
	var y := y0
	while y < y1:
		var short := _rng.randf() < 0.15
		_box(x, y, w * (_rng.randf_range(0.3, 0.7) if short else 1.0), 1.1, Color(GREY, 0.5))
		y += 3.0 if not short else 5.0


func _stick(feet: Vector2, h: float, hands: Array, face := "plain", col := INK) -> Dictionary:
	## A stick figure standing at `feet`, `h` tall. `hands` are where its two
	## hands go, from its shoulders. Returns its head, shoulders and hands.
	var head := feet + Vector2(0, -h * 0.85)
	var neck := feet + Vector2(0, -h * 0.7)
	var hip := feet + Vector2(0, -h * 0.35)
	var r := h * 0.15
	draw_arc(_p(head.x, head.y), r * _s, 0, TAU, 20, col, maxf(0.6 * _s, 1.0), true)
	_line(neck, hip, col)
	_line(hip, feet + Vector2(-h * 0.15, 0), col)
	_line(hip, feet + Vector2(h * 0.15, 0), col)
	var sh := neck + Vector2(0, h * 0.06)
	var out := []
	for k in 2:
		var hand: Vector2 = sh + hands[k]
		_line(sh, hand, col)
		out.append(hand)
	var eye := r * 0.35
	match face:
		"shocked":
			for sx in [-1, 1]:
				draw_circle(_p(head.x + sx * eye, head.y - r * 0.2), r * 0.16 * _s, col)
			draw_arc(_p(head.x, head.y + r * 0.4), r * 0.25 * _s, 0, TAU, 12, col, maxf(0.5 * _s, 1.0))
		"grin":
			for sx in [-1, 1]:
				draw_circle(_p(head.x + sx * eye, head.y - r * 0.2), r * 0.12 * _s, col)
			draw_arc(_p(head.x, head.y + r * 0.05), r * 0.5 * _s, 0.3, PI - 0.3, 10, col, maxf(0.5 * _s, 1.0))
		_:
			for sx in [-1, 1]:
				draw_circle(_p(head.x + sx * eye, head.y - r * 0.2), r * 0.12 * _s, col)
	return {"head": head, "shoulder": sh, "hands": out}


func _poly(points: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for q in points:
		pts.append(_p(q.x, q.y))
	draw_colored_polygon(pts, col)


func _outline(points: Array, col := INK, width := 0.6) -> void:
	var pts := PackedVector2Array()
	for q in points:
		pts.append(_p(q.x, q.y))
	pts.append(pts[0])
	draw_polyline(pts, col, maxf(width * _s, 1.0), true)


func _stamp(text: String, at: Vector2, angle: float, size: float, col: Color) -> void:
	## Text turned at an angle, centred on `at` (a rubber stamp, a banner).
	var px := maxi(roundi(size * _s), 6)
	var w := _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_set_transform(_p(at.x, at.y), angle)
	draw_string(_bold, Vector2(-w * 0.5, _bold.get_ascent(px) * 0.4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	draw_set_transform(Vector2.ZERO, 0.0)


# --- The pages -------------------------------------------------------------------------

func _safety_report() -> void:
	draw_rect(_r, WHITE)
	var y := _text("ConCERNing Labs", 7, 3.6, GREY, true, HORIZONTAL_ALIGNMENT_LEFT)
	_line(Vector2(8, y + 1), Vector2(92, y + 1), GREY, 0.4)
	y = _text("SAFETY REVIEW: LAB 4 ACCELERATOR", y + 4, 5.2, INK, true, HORIZONTAL_ALIGNMENT_LEFT)
	y = _text("Findings", y + 4, 4.0, INK, true, HORIZONTAL_ALIGNMENT_LEFT)
	for f in ["1. Field readings near the ring are off every scale we own, the bathroom scale included.",
			"2. Some parts were made off site, somewhere described only as \"damp\".",
			"3. The night shift is one intern and a coffee pot.",
			"4. Nobody can say what the machine is for."]:
		y = _text(f, y + 1.5, 3.4, INK, false, HORIZONTAL_ALIGNMENT_LEFT, 10, 80)
	_filler(y + 6, 130)
	# A coffee ring.
	draw_arc(_p(22, 120), 8.0 * _s, 0.4, TAU - 0.2, 32, Color(0.45, 0.28, 0.12, 0.45), 1.6 * _s, true)


func _magazine() -> void:
	draw_rect(_r, WHITE)
	_box(3, 3, 94, 1.0 / ASPECT * 100.0 - 6, Color(0.98, 0.8, 0.1), false, 3.5)
	var y := _text("NATIONALLY GRAPHIC", 9, 7.6, INK, true)
	y = _text("Vaguely Carboniferous", y + 1, 4.4, GREY)
	var pic := Rect2(12, y + 5, 76, 126 - y - 5)
	_box(pic.position.x, pic.position.y, pic.size.x, pic.size.y, Color(0.03, 0.03, 0.03))
	var c := pic.get_center()
	_stamp("CENSORED", c, -atan2(pic.size.y, pic.size.x), 11.0, Color(0.95, 0.95, 0.92))


func _masthead() -> float:
	draw_rect(_r, NEWSPRINT)
	var y := _text("THE DAILY GAZETTE", 5, 6.0, INK, true)
	_line(Vector2(6, y + 1), Vector2(94, y + 1), INK, 0.8)
	_line(Vector2(6, y + 2.2), Vector2(94, y + 2.2), INK, 0.3)
	return y + 5


func _paper_headline(head: String, body: String, picture: Callable) -> void:
	var y := _masthead()
	y = _text(head, y, 6.6, INK, true)
	if picture.is_valid():
		var pic := Rect2(10, y + 3, 80, 44)
		_box(pic.position.x, pic.position.y, pic.size.x, pic.size.y, NEWSPRINT.lightened(0.25))
		picture.call(pic)
		_box(pic.position.x, pic.position.y, pic.size.x, pic.size.y, INK, false, 0.5)
		y = pic.end.y
	y = _text(body, y + 4, 3.7, INK, false, HORIZONTAL_ALIGNMENT_LEFT)
	_line(Vector2(6, y + 3), Vector2(94, y + 3), INK, 0.3)
	_filler(y + 6, 132, 8, 40)
	_filler(y + 6, 132, 52, 40)


func _hunter(pic: Rect2) -> void:
	# The petting zoo: the manager has just beaned a bunny with a rock, a spare
	# handful at the ready, while another rock keeps the llama busy.
	var x0 := pic.position.x
	var ground := pic.end.y - 5
	_box(x0, ground, pic.size.x, pic.end.y - ground, Color(0.62, 0.66, 0.5))
	# The fence along the back.
	var wood := Color(0.55, 0.45, 0.33)
	for k in 9:
		var px := x0 + 3 + k * 9.5
		_box(px, ground - 15, 1.4, 15, wood)
	for ry in [ground - 12.5, ground - 6]:
		_box(x0 + 1, ry, pic.size.x - 2, 1.2, wood)
	# The manager, follow-through after the throw, spare rocks in the other hand.
	var me := _stick(Vector2(x0 + 12, ground), 30, [Vector2(10, -7), Vector2(-6, 7)], "grin")
	var stone := Color(0.45, 0.44, 0.42)
	for k in 3:
		draw_circle(_p(me.hands[1].x - 1.2 + k * 1.3, me.hands[1].y + 0.6 - (k % 2) * 1.0), 1.1 * _s, stone)
	# The rock's path to the bunny, which is out cold.
	var from: Vector2 = me.hands[0]
	var bunny := Vector2(x0 + 33, ground - 2.6)
	for k in 6:
		var q := (k + 1) / 7.0
		var at := from.lerp(bunny + Vector2(-5, -4), q) + Vector2(0, -8.0 * q * (1.0 - q) * 4.0)
		draw_circle(_p(at.x, at.y), 0.45 * _s, INK)
	draw_circle(_p(bunny.x + 8, ground - 1.2), 1.4 * _s, stone)
	var fur := Color(0.72, 0.64, 0.56)
	for k in 2:  # legs in the air
		_line(bunny + Vector2(-1 + k * 4, -2), bunny + Vector2(-2 + k * 5.5, -6), fur.darkened(0.3), 1.0)
	var body := []
	for k in 16:
		var a := TAU * k / 16.0
		body.append(bunny + Vector2(cos(a) * 5.5, sin(a) * 2.8))
	_poly(body, fur)
	_outline(body, INK, 0.4)
	var face := bunny + Vector2(-6, -0.4)
	for k in 2:  # ears flopped on the grass
		var ear := []
		for j in 10:
			var a := TAU * j / 10.0
			ear.append(face + Vector2(-4.5 + cos(a) * 3.2, 0.6 + k * 1.6 + sin(a) * 0.9))
		_poly(ear, fur.darkened(0.1))
		_outline(ear, INK, 0.3)
	draw_circle(_p(face.x, face.y), 2.4 * _s, fur)
	draw_arc(_p(face.x, face.y), 2.4 * _s, 0, TAU, 16, INK, maxf(0.4 * _s, 1.0), true)
	var eye := face + Vector2(-0.6, -0.6)
	_line(eye + Vector2(-0.7, -0.7), eye + Vector2(0.7, 0.7), INK, 0.35)
	_line(eye + Vector2(-0.7, 0.7), eye + Vector2(0.7, -0.7), INK, 0.35)
	for k in 3:  # seeing stars
		var st := face + Vector2(-3 + k * 3, -5 - (k % 2) * 1.6)
		_line(st + Vector2(-1, 0), st + Vector2(1, 0), Color(0.8, 0.6, 0.1), 0.45)
		_line(st + Vector2(0, -1), st + Vector2(0, 1), Color(0.8, 0.6, 0.1), 0.45)
	# The llama, looking the other way at the rock that just landed by it.
	var fleece := Color(0.78, 0.66, 0.48)
	var lx := x0 + 65
	var hip := Vector2(lx, ground - 9)
	for k in 4:
		_box(lx - 5.8 + k * 3.4, hip.y, 1.6, ground - hip.y, fleece.darkened(0.15 + 0.1 * (k % 2)))
	var torso := []
	for k in 16:
		var a := TAU * k / 16.0
		torso.append(hip + Vector2(cos(a) * 7.0, sin(a) * 3.6 - 1.5))
	_poly(torso, fleece)
	var neck := hip + Vector2(5, -3)
	_poly([neck + Vector2(-1.5, 0), neck + Vector2(1.6, 0), neck + Vector2(4.0, -14), neck + Vector2(1.0, -14)], fleece)
	var head := neck + Vector2(3.5, -15)
	_poly([head + Vector2(-2.5, -1.5), head + Vector2(5.5, -0.6), head + Vector2(5.5, 1.6), head + Vector2(-2.5, 2)], fleece)
	_poly([head + Vector2(-1.8, -1.4), head + Vector2(-1.4, -4.4), head + Vector2(-0.4, -1.4)], fleece.darkened(0.2))
	draw_circle(_p(head.x + 1.2, head.y - 0.1), 0.5 * _s, INK)
	var lure := Vector2(pic.end.x - 3, ground - 1)
	draw_circle(_p(lure.x, lure.y), 1.5 * _s, stone)
	for k in 3:
		var d := Vector2(-0.6 + k * 0.6, -1).normalized()
		_line(lure + d * 2.2, lure + d * 3.8, INK, 0.3)
	_text("?", head.y - 9, 4.0, INK, true, HORIZONTAL_ALIGNMENT_LEFT, head.x + 2.5, 6)


func _alligator(pic: Rect2) -> void:
	# A man takes a selfie as a giant alligator lunges out of the water at him.
	var water := pic.end.y - 9
	_box(pic.position.x, water, pic.size.x, pic.end.y - water, Color(0.55, 0.65, 0.68))
	for k in 6:
		var x := pic.position.x + 4 + k * 13
		_line(Vector2(x, water + 3), Vector2(x + 5, water + 2), Color(0.3, 0.4, 0.45), 0.4)
	var man := _stick(Vector2(pic.position.x + 18, water), 30, [Vector2(-9, -9), Vector2(6, 6)], "shocked")
	var phone: Vector2 = man.hands[0]
	_box(phone.x - 2, phone.y - 4, 3, 5, INK)
	# The alligator: rearing out of the water behind him, jaws wide.
	var g := Color(0.33, 0.45, 0.25)
	var hinge := Vector2(pic.position.x + 58, water - 14)
	_poly([hinge + Vector2(-2, -7), hinge + Vector2(12, -10), Vector2(pic.end.x - 1, water - 9), Vector2(pic.end.x - 1, water + 1),
			Vector2(hinge.x - 4, water + 1), hinge + Vector2(1, 6)], g)
	var upper := [hinge + Vector2(1, -8), hinge + Vector2(-25, -19), hinge + Vector2(-26, -15), hinge]
	var lower := [hinge, hinge + Vector2(-22, 3), hinge + Vector2(-21, 7), hinge + Vector2(3, 6)]
	_poly(upper, g)
	_poly(lower, g.darkened(0.15))
	_poly([hinge, hinge + Vector2(-26, -15), hinge + Vector2(-22, 3)], Color(0.75, 0.4, 0.4))  # the inside of its mouth
	for k in 5:
		var t := (k + 0.6) / 5.5
		var a: Vector2 = hinge.lerp(upper[2], t)
		_poly([a + Vector2(-1.2, 0), a + Vector2(1.2, 0.6), a + Vector2(0.2, 2.8)], WHITE)
		var b: Vector2 = hinge.lerp(lower[1], t)
		_poly([b + Vector2(-1.2, 0), b + Vector2(1.2, 0.2), b + Vector2(-0.2, -2.6)], WHITE)
	draw_circle(_p(hinge.x + 3, hinge.y - 10), 1.6 * _s, Color(0.9, 0.8, 0.2))
	draw_circle(_p(hinge.x + 3.3, hinge.y - 10), 0.6 * _s, INK)
	for k in 5:
		var at := hinge + Vector2(12, -10)
		at = at.lerp(Vector2(pic.end.x - 1, water - 9), (k + 0.5) / 5.0)
		_poly([at + Vector2(-2, 0.3), at + Vector2(0, -2.5), at + Vector2(2, -0.3)], g.darkened(0.25))


func _stove(pic: Rect2) -> void:
	# A crude pot on a stovetop, steaming.
	var top := pic.end.y - 12
	_box(pic.position.x + 14, top, 52, 10, Color(0.85, 0.85, 0.82))
	_box(pic.position.x + 14, top, 52, 10, INK, false, 0.4)
	for k in 3:
		draw_circle(_p(pic.position.x + 24 + k * 16, top + 6), 1.4 * _s, INK)
	var c := Vector2(pic.position.x + 40, top)
	draw_arc(_p(c.x, c.y + 0.4), 9 * _s, PI, TAU, 12, Color(0.8, 0.25, 0.1), 1.0 * _s)
	_poly([c + Vector2(-12, -18), c + Vector2(12, -18), c + Vector2(10, -1), c + Vector2(-10, -1)], Color(0.5, 0.5, 0.53))
	_outline([c + Vector2(-12, -18), c + Vector2(12, -18), c + Vector2(10, -1), c + Vector2(-10, -1)])
	_line(c + Vector2(12, -15), c + Vector2(22, -17), INK, 1.0)
	_line(c + Vector2(-13, -18.4), c + Vector2(13, -18.4), INK, 0.8)
	for k in 3:
		var x := c.x - 7 + k * 7
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(_p(x + sin(i * 1.1 + k) * 1.4, c.y - 20.5 - i * 1.6))
		draw_polyline(pts, GREY, maxf(0.5 * _s, 1.0), true)


func _poster(head: String, tag: String, item: String, price: String, camo: Color) -> void:
	draw_rect(_r, camo)
	for k in 26:
		var at := Vector2(_rng.randf_range(0, 100), _rng.randf_range(0, 139))
		var pts := []
		for i in 7:
			var a := TAU * i / 7.0
			pts.append((at + Vector2(cos(a), sin(a)) * _rng.randf_range(4, 9)).clamp(Vector2.ZERO, Vector2(100, 100 / ASPECT)))
		_poly(pts, camo.darkened(_rng.randf_range(0.15, 0.4)) if k % 2 == 0 else camo.lightened(0.12))
	_box(4, 5, 92, 22, Color(0, 0, 0, 0.72))
	var big := 7.4
	var wide := _bold.get_string_size(head.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(big * _s)).x / _s
	big = minf(big, big * 82.0 / maxf(wide, 1.0))  # on one line
	_text(head.to_upper(), 16 - big * 0.75, big, Color(1.0, 0.82, 0.15), true)
	var y := _text(tag, 32, 4.0, WHITE, true)
	var pic := Rect2(_p(16, y + 4), Vector2(68, 68) * _s)
	draw_circle(pic.get_center(), pic.size.x * 0.48, Color(1, 1, 1, 0.82))
	Icons.draw_item(self, pic.grow(-pic.size.x * 0.08), item)
	_box(0, 116, 100, 16, Color(0.75, 0.12, 0.1))
	_text(price, 119.5, 4.6, WHITE, true)


func _diary() -> void:
	# Printer paper, in a child's capitals.
	draw_rect(_r, WHITE)
	var text := "DEAR DIARY\nTODAY I LEARNED SITTING IN THE MUD IS HARDER THAN WORKING AT A TABLE. ITS HARD MAKING PARTICLE ACCELERATOR PARTS LIKE THAT. I ALSO DRANK PUDDLE WATER AND MY TUMMY HURTS. I'LL GO HOME NOW. INTERN CRAIG CAN FINISH THE ACCELERATOR TONIGHT."
	var px := maxi(roundi(5.0 * _s), 7)
	var x0 := 9.0 * _s
	var width := 82.0 * _s
	var y := 16.0 * _s
	var lh := px * 1.55
	for para in text.split("\n"):
		var x := x0
		for word in para.split(" "):
			var ww := _font.get_string_size(word + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * 1.08
			if x + ww > x0 + width and x > x0:
				x = x0
				y += lh
			for ch in word:
				var sz := px + _rng.randi_range(-1, 3)
				var at := _r.position + Vector2(x, y + _rng.randf_range(-2.0, 2.0) * _s * 0.4)
				draw_char(_font, at, ch, sz, PENCIL)
				draw_char(_font, at + Vector2(0.6, 0.3), ch, sz, Color(PENCIL, 0.5))
				x += _font.get_char_size(ch.unicode_at(0), sz).x * 1.08
			x += _font.get_char_size(32, px).x * 1.6
		y += lh * 1.3
	# A muddy thumbprint in the corner.
	draw_circle(_p(84, 126), 4.5 * _s, Color(0.38, 0.29, 0.18, 0.55))
	for k in 4:
		draw_arc(_p(84, 126), (1.0 + k) * _s, 0.3, TAU - 0.6, 16, Color(0.3, 0.22, 0.12, 0.5), maxf(0.3 * _s, 1.0))
