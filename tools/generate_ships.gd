extends SceneTree
## Draws the M5 ship art with code (ART_SPEC §9, ROADMAP M5 part 1): the fishing boat in 8
## directions (moored, rowing, casting, waiting and hauling the net), the boat on the slipway
## by building stage, and an animated fish shoal.
##
## Run: "$GODOT" --headless --path . -s res://tools/generate_ships.gd
##
## Boat sheets: one row per direction (IsoMath.Dir: S, SE, E, NE, N, NW, W, SW), one column
## per frame of BOAT_FRAME; the boat centre at the waterline is at BOAT_PIVOT of every frame.
## The boat is a small 3D model (hull rings, thwarts, oars, a fisherman) projected with
## IsoMath like the buildings, lit from the left, with a dark outline.

const OUT := "res://assets"
const BOAT_FRAME := Vector2i(80, 64)
const BOAT_PIVOT := Vector2(40, 46)
const SHOAL_FRAME := Vector2i(64, 48)
const SHOAL_PIVOT := Vector2(32, 32)

## Half length and half beam in tiles, gunwale height in px.
const LENGTH := 0.72
const BEAM := 0.24
const GUNWALE := 6.0
const SHEER := 3.0

const C_HULL := Color(0.45, 0.3, 0.18)
const C_TARRED := Color(0.2, 0.15, 0.12)
const C_INSIDE := Color(0.62, 0.45, 0.28)
const C_THWART := Color(0.72, 0.55, 0.34)
const C_OAR := Color(0.78, 0.64, 0.42)
const C_SHIRT := Color(0.3, 0.42, 0.55)
const C_SKIN := Color(0.93, 0.74, 0.58)
const C_HAT := Color(0.75, 0.62, 0.3)
const C_NET := Color(0.82, 0.8, 0.7)
const C_CORK := Color(0.85, 0.55, 0.25)
const C_FOAM := Color(0.86, 0.93, 0.95)
const C_FISH := Color(0.78, 0.84, 0.88)

## Animation -> frames.
const BOAT_ANIMS := {"idle": 1, "row": 4, "cast_net": 4, "wait_net": 4, "haul_net": 4}

var _img: Image
var _pivot: Vector2
var _fwd: Vector2
var _right: Vector2


func _init() -> void:
	for anim: String in BOAT_ANIMS:
		_save(_boat_sheet(anim, BOAT_ANIMS[anim]), "ships/fishing_boat/%s.png" % anim)
	for stage: int in 2:
		_save(_boat_sheet("build_%d" % stage, 1), "ships/fishing_boat/build_%d.png" % stage)
	_save(_shoal_sheet(), "nature/fish_shoal/shoal.png")
	print("Ship art written to ", OUT)
	quit()


# --- Boat ----------------------------------------------------------------------------------

func _boat_sheet(anim: String, frames: int) -> Image:
	var sheet := Image.create_empty(BOAT_FRAME.x * frames, BOAT_FRAME.y * IsoMath.DIR_COUNT, false, Image.FORMAT_RGBA8)
	for dir: int in IsoMath.DIR_COUNT:
		for frame: int in frames:
			_img = Image.create_empty(BOAT_FRAME.x, BOAT_FRAME.y, false, Image.FORMAT_RGBA8)
			_pivot = BOAT_PIVOT
			_fwd = Vector2(IsoMath.DIR_GRID_STEP[dir]).normalized()
			_right = Vector2(-_fwd.y, _fwd.x)
			_boat(anim, frame / float(frames))
			_outline(_img)
			_extras(anim, frame / float(frames))
			sheet.blit_rect(_img, Rect2i(Vector2i.ZERO, BOAT_FRAME), Vector2i(frame * BOAT_FRAME.x, dir * BOAT_FRAME.y))
	return sheet


## Screen point of a boat-local point: along (tiles), side (tiles, + = starboard), z (px).
func _p(along: float, side: float, z: float) -> Vector2:
	var g := _fwd * along + _right * side
	return _pivot + IsoMath.grid_to_screen(g) - Vector2(0, z)


func _half_width(t: float) -> float:
	return BEAM * pow(maxf(1.0 - t * t, 0.0), 0.55)


func _gunwale_z(t: float) -> float:
	return GUNWALE + SHEER * t * t


func _boat(anim: String, t: float) -> void:
	var building := anim.begins_with("build_")
	var stage := int(anim.trim_prefix("build_")) if building else 1
	var bob := 0.0 if building else roundf(sin(t * TAU) * 0.6)
	_pivot = BOAT_PIVOT + Vector2(0, bob)
	# Which side faces the camera (grid +x +y is towards the viewer).
	var near := 1.0 if _right.dot(Vector2(1, 1)) > 0.0 else -1.0
	var steps := 14
	if stage == 0:
		# The frame: keel, stem and stern posts and the ribs, no planks yet.
		_line(_p(-LENGTH, 0, 0.5), _p(LENGTH, 0, 0.5), C_HULL.darkened(0.2), 2)
		_line(_p(LENGTH, 0, 0), _p(LENGTH, 0, _gunwale_z(1.0) + 1.0), C_HULL, 2)
		_line(_p(-LENGTH, 0, 0), _p(-LENGTH, 0, _gunwale_z(1.0)), C_HULL, 2)
		for k: int in range(1, 8):
			var a := -LENGTH + 2.0 * LENGTH * k / 8.0
			var w := _half_width(a / LENGTH)
			for side: float in [-near, near]:
				_line(_p(a, 0, 0.5), _p(a, side * w, _gunwale_z(a / LENGTH)), C_HULL.lightened(0.1), 1)
		return
	# Far side (inside visible), floor, thwarts, crew, near side.
	_side(-near, steps, true)
	var floor := PackedVector2Array()
	for i: int in steps + 1:
		var a := -LENGTH * 0.85 + 1.7 * LENGTH * i / steps
		floor.append(_p(a, _half_width(a / LENGTH) * 0.7, 1.5))
	for i: int in steps + 1:
		var a := LENGTH * 0.85 - 1.7 * LENGTH * i / steps
		floor.append(_p(a, -_half_width(a / LENGTH) * 0.7, 1.5))
	_poly(floor, C_INSIDE.darkened(0.25))
	for a: float in [-0.35, 0.3]:
		var w := _half_width(a / LENGTH)
		_line(_p(a, -w, GUNWALE - 1.0), _p(a, w, GUNWALE - 1.0), C_THWART, 2)
	var crew := anim in BOAT_ANIMS and anim != "idle"
	if crew:
		_fisherman(anim, t)
	else:
		# A coil of rope and a basket lie in the empty boat.
		_ellipse(_p(-0.4, 0.0, 3.0), Vector2(3, 1.5), Color(0.6, 0.5, 0.35))
		_ellipse(_p(0.42, 0.0, 4.0), Vector2(3, 2), Color(0.68, 0.52, 0.3))
	_side(near, steps, false)


## Drawn after the outline: water around the boat, oars and the net (thin, not outlined).
func _extras(anim: String, t: float) -> void:
	if anim.begins_with("build_"):
		return
	var near := 1.0 if _right.dot(Vector2(1, 1)) > 0.0 else -1.0
	_ripples(anim, t)
	if anim == "row":
		_oars(t, near)
	if anim in ["cast_net", "wait_net", "haul_net"]:
		_net(anim, t)


## One side of the hull: the outer planks from the gunwale down to the waterline (tarred
## below a stripe), or, for the far side, the inside of the planks seen over the near gunwale.
func _side(side: float, steps: int, far: bool) -> void:
	var top: Array[Vector2] = []
	var bottom: Array[Vector2] = []
	for i: int in steps + 1:
		var a := -LENGTH + 2.0 * LENGTH * i / steps
		var w := _half_width(a / LENGTH)
		top.append(_p(a, side * w, _gunwale_z(a / LENGTH)))
		bottom.append(_p(a, side * w * 0.75, 0.0))
	var poly := PackedVector2Array()
	for p: Vector2 in top:
		poly.append(p)
	for i: int in range(bottom.size() - 1, -1, -1):
		poly.append(bottom[i])
	var light := 1.05 if _right.dot(Vector2(1, -1)) * side < 0.0 else 0.82
	if far:
		_poly(poly, C_INSIDE.darkened(0.05) * light)
	else:
		_poly(poly, C_HULL * light)
		# The tarred bottom strake and a plank line.
		var tar := PackedVector2Array()
		for i: int in steps + 1:
			tar.append(bottom[i].lerp(top[i], 0.3))
		for i: int in range(steps, -1, -1):
			tar.append(bottom[i])
		_poly(tar, C_TARRED)
		for i: int in steps:
			_line(bottom[i].lerp(top[i], 0.62), bottom[i + 1].lerp(top[i + 1], 0.62), (C_HULL * light).darkened(0.22), 1)
	for i: int in steps:
		_line(top[i], top[i + 1], C_THWART.darkened(0.1), 1)


## The fisherman on the middle thwart.
func _fisherman(anim: String, t: float) -> void:
	var seat := _p(-0.05, 0, GUNWALE)
	var lean := 0.0
	var arms := 0.0
	match anim:
		"row":
			lean = sin(t * TAU) * 2.0
		"cast_net":
			arms = 1.0 - absf(1.0 - 2.0 * t)
		"haul_net":
			lean = -1.5 + sin(t * TAU) * 1.5
	var back := IsoMath.grid_to_screen(_fwd).normalized()
	var body := seat - Vector2(0, 7) - back * lean
	_ellipse(body, Vector2(3.5, 5.0), C_SHIRT)
	_ellipse(body - Vector2(0, 7), Vector2(2.5, 2.5), C_SKIN)
	_ellipse(body - Vector2(0, 9), Vector2(4.5, 1.5), C_HAT)
	_ellipse(body - Vector2(0, 10), Vector2(2.5, 1.5), C_HAT.darkened(0.1))
	if arms > 0.0:
		_line(body - Vector2(2, 3), body + Vector2(-5, -6 - arms * 6.0), C_SKIN, 1)
		_line(body - Vector2(-2, 3), body + Vector2(5, -6 - arms * 6.0), C_SKIN, 1)


## Oars dipping in and out, from the oarlocks on both sides.
func _oars(t: float, near: float) -> void:
	var swing := sin(t * TAU) * 0.22
	var lift := maxf(cos(t * TAU), 0.0) * 4.0
	for side: float in [-near, near]:
		var lock := _p(0.0, side * _half_width(0.0), GUNWALE + 1.0)
		var blade := _p(-swing, side * (BEAM + 0.42), lift)
		_line(lock, blade, C_OAR, 1)
		if lift < 1.0:
			_px(blade + Vector2(1, 1), C_FOAM)


## The net: thrown out in an arc, floating as a line of corks, or hauled in with fish.
func _net(anim: String, t: float) -> void:
	match anim:
		"cast_net":
			var reach := 0.25 + 0.45 * t
			for k: int in 7:
				var a := -0.4 + 0.8 * k / 6.0
				var p := _p(a * 0.8, reach + BEAM, 10.0 * sin(PI * t) + 2.0)
				_px(p, C_NET)
				_px(p + Vector2(0, 1), C_NET.darkened(0.2))
		"wait_net":
			for k: int in 7:
				var a := -0.5 + 1.0 * k / 6.0
				var p := _p(a, BEAM + 0.55 + sin(t * TAU + k) * 0.02, 0.0)
				_px(p, C_CORK)
				if (k + int(t * 4.0)) % 3 == 0:
					_px(p + Vector2(1, 0), C_FOAM)
		"haul_net":
			var lock := _p(0.1, BEAM, GUNWALE)
			var out := _p(0.0, BEAM + 0.5 * (1.0 - t), 0.0)
			_line(lock, out, C_NET, 1)
			for k: int in 3:
				var fish := lock.lerp(out, 0.3 + 0.2 * k) + Vector2(0, -1)
				_px(fish, C_FISH)
				if (k + int(t * 4.0)) % 2 == 0:
					_px(fish + Vector2(1, -1), Color.WHITE)


## Rings of small waves around the hull; a wake behind a rowing boat.
func _ripples(anim: String, t: float) -> void:
	for k: int in 10:
		var a := TAU * k / 10.0 + t * 0.6
		var p := _p(cos(a) * (LENGTH + 0.12), sin(a) * (BEAM + 0.1), 0.0)
		if (k + int(t * 8.0)) % 3 != 0:
			_px(p, C_FOAM.darkened(0.15))
	if anim == "row":
		for k: int in 4:
			var d := LENGTH + 0.15 + k * 0.14
			var w := 0.06 + k * 0.05
			if (k + int(t * 4.0)) % 2 == 0:
				_px(_p(-d, w, 0.0), C_FOAM)
				_px(_p(-d, -w, 0.0), C_FOAM)


# --- Shoal ---------------------------------------------------------------------------------

## Fish shoal: 4 frames of 3 rows (full, fished, empty). Dark fish shapes under the water,
## splashes and a jumping fish, a gull circling over a full shoal.
func _shoal_sheet() -> Image:
	var frames := 4
	var sheet := Image.create_empty(SHOAL_FRAME.x * frames, SHOAL_FRAME.y * 3, false, Image.FORMAT_RGBA8)
	for state: int in 3:
		for frame: int in frames:
			_img = Image.create_empty(SHOAL_FRAME.x, SHOAL_FRAME.y, false, Image.FORMAT_RGBA8)
			_pivot = SHOAL_PIVOT
			var t := frame / float(frames)
			var count: int = [9, 5, 0][state]
			if state < 2:
				# A ruffled, lighter patch of water where the fish crowd.
				for k: int in 40:
					var a := TAU * k / 40.0
					var r := 0.3 + 0.08 * sin(k * 1.7 + t * TAU)
					var q := _pivot + IsoMath.grid_to_screen(Vector2(cos(a), sin(a)) * r * (1.0 - 0.3 * state))
					if (k + frame) % 2 == 0:
						_px(q, Color(0.6, 0.78, 0.86, 0.6))
			for k: int in count:
				var a := TAU * k / maxf(count, 1) + t * TAU * 0.25
				var r := 0.18 + 0.12 * float((k * 7) % 3)
				var p := _pivot + IsoMath.grid_to_screen(Vector2(cos(a), sin(a)) * r)
				_line(p, p + Vector2(3, 1).rotated(a + t), Color(0.06, 0.14, 0.22, 0.9), 2)
				if (k + frame) % 3 == 0:
					_px(p + Vector2(1, -1), Color(0.85, 0.92, 0.95))
			if state < 2:
				for k: int in 3 - state:
					var phase := fmod(t + k * 0.37, 1.0)
					var p := _pivot + IsoMath.grid_to_screen(Vector2(cos(k * 2.1), sin(k * 2.1)) * 0.25)
					if phase < 0.5:
						var r := 1.0 + phase * 6.0
						_ellipse_ring(p, Vector2(r, r * 0.5), C_FOAM)
				if frame == 1 or frame == 2:
					var jump := _pivot + Vector2(-4 + frame * 3, -3 - (2 if frame == 1 else 3))
					_line(jump, jump + Vector2(3, 1), C_FISH, 2)
			if state == 0:
				var gull := _pivot + Vector2(cos(t * TAU) * 12.0, -24.0 + sin(t * TAU) * 3.0)
				_line(gull + Vector2(-4, -1 - (frame % 2)), gull, Color.WHITE, 1)
				_line(gull, gull + Vector2(4, -1 - (frame % 2)), Color.WHITE, 1)
				_px(gull + Vector2(0, 1), Color(0.6, 0.6, 0.62))
			sheet.blit_rect(_img, Rect2i(Vector2i.ZERO, SHOAL_FRAME), Vector2i(frame * SHOAL_FRAME.x, state * SHOAL_FRAME.y))
	return sheet


# --- Drawing -------------------------------------------------------------------------------

func _poly(points: PackedVector2Array, colour: Color) -> void:
	var rect := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		rect = rect.expand(p)
	for y: int in range(floori(rect.position.y), ceili(rect.end.y) + 1):
		for x: int in range(floori(rect.position.x), ceili(rect.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				_px(Vector2(x, y), colour)


func _line(a: Vector2, b: Vector2, colour: Color, width: int) -> void:
	var n := maxi(ceili(a.distance_to(b) * 2.0), 1)
	for i: int in n + 1:
		var p := a.lerp(b, i / float(n))
		for dx: int in width:
			for dy: int in width:
				_px(p + Vector2(dx - width / 2, dy - width / 2), colour)


func _ellipse(centre: Vector2, radius: Vector2, colour: Color) -> void:
	for y: int in range(floori(centre.y - radius.y), ceili(centre.y + radius.y) + 1):
		for x: int in range(floori(centre.x - radius.x), ceili(centre.x + radius.x) + 1):
			var d := (Vector2(x + 0.5, y + 0.5) - centre) / radius
			if d.length_squared() <= 1.0:
				_px(Vector2(x, y), colour)


func _ellipse_ring(centre: Vector2, radius: Vector2, colour: Color) -> void:
	for k: int in 16:
		var a := TAU * k / 16.0
		_px(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y), colour)


func _px(p: Vector2, colour: Color) -> void:
	var q := Vector2i(floori(p.x), floori(p.y))
	if q.x >= 0 and q.y >= 0 and q.x < _img.get_width() and q.y < _img.get_height():
		_img.set_pixelv(q, colour.blend(Color(0, 0, 0, 0)) if colour.a < 1.0 and _img.get_pixelv(q).a == 0.0 \
				else _img.get_pixelv(q).blend(colour))


## Dark outline around the opaque shape of the boat (not around lone foam pixels).
func _outline(img: Image) -> void:
	var size := img.get_size()
	var edge: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			var c := img.get_pixel(x, y)
			if c.a < 0.99:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if not Rect2i(Vector2i.ZERO, size).has_point(q) or img.get_pixelv(q).a == 0.0:
					edge.append(Vector2i(x, y))
					break
	for p: Vector2i in edge:
		var c := img.get_pixelv(p)
		img.set_pixelv(p, Color(c.r * 0.35, c.g * 0.3, c.b * 0.28, 1.0))


func _save(img: Image, relative: String) -> void:
	var path := OUT.path_join(relative)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := img.save_png(path)
	if err != OK:
		push_error("Cannot save %s (%s)" % [path, error_string(err)])
