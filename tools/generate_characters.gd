extends SceneTree
## The stud farm's horses as goods drawn in code (M7 part 1, ART_SPEC §10.14): the herd stack, the
## led horse. Every person (townsfolk, soldiers, bandits) is drawn with SpriteKiln
## since G3 (ART_SPEC §10.27); their old code drawings were removed in the G3 clean-up (2026-11-14),
## the old look stays in git history.
##
## Run: godot --headless --path . -s res://tools/generate_characters.gd   (then --import)

const FOOT := Vector2(32, 58)
const ROWS := 5
## People are drawn for 42 px and shrunk to about 34 px around the feet (owner decision
## 2026-11-05: closer to the size of doors and windows).
const SCALE := 0.81
## The kingdom's colours (the player's arms on the world map, M6): tabards, shields, pennons.
const ROYAL := Color(0.70, 0.12, 0.10)
const GOLD := Color(0.92, 0.74, 0.26)
const C_LEATHER := Color(0.46, 0.3, 0.18)
## Horse colours (the knight's mount and the stud farm's herd).
const HORSE := {"coat": Color(0.48, 0.3, 0.17), "mane": Color(0.18, 0.12, 0.09), "hoof": Color(0.22, 0.18, 0.15),
		"blaze": Color(0.92, 0.9, 0.84)}

var _look: Dictionary
## Livery of the soldier being drawn: the kingdom's red and gold, a bandit's drab ones.
var _royal: Color = ROYAL
var _gold: Color = GOLD
## Parts of the frame being drawn: [depth, callable].
var _parts: Array = []
var _forward: Vector2
var _right: Vector2


func _init() -> void:
	_horse_goods()
	print("Horse goods written")
	quit()


## A horse in body space under the rider (or alone for the herd): body, neck and head along
## [member _forward], legs in a walking gait ([param swing] -1..1 over a stride), the tail
## swishing. [param barded]: the kingdom's cloth and a saddle (a knight's mount).
func _horse(foot: Vector2, swing: float, t: float, breath: float, barded: bool) -> void:
	var coat: Color = HORSE["coat"]
	var mane: Color = HORSE["mane"]
	var gait := swing
	# Legs: front at f +5, hind at f -6; diagonal pairs move together.
	for leg: Array in [[2.0, 5.0, 1.0], [-2.0, 5.0, -1.0], [2.0, -6.0, -1.0], [-2.0, -6.0, 1.0]]:
		var s: float = leg[0]
		var f: float = leg[1]
		var phase: float = leg[2] * gait
		var top := Vector3(s, f, 12.0)
		var knee := Vector3(s, f + phase * 1.6 + (0.6 if f > 0 else -0.6), 6.5 + absf(phase) * 0.8)
		var hoof := Vector3(s, f + phase * 3.0, 0.8 + maxf(phase, 0.0) * 1.2)
		var shade := coat.darkened(0.12 if s < 0 else 0.0)
		_limb(foot, top, knee, 2.4, shade)
		_limb(foot, knee, hoof, 1.8, shade.darkened(0.05))
		_blob(foot, hoof + Vector3(0, 0.4, -0.4), Vector2(1.4, 0.9), HORSE["hoof"])
	# Body, neck, head.
	var lift := breath * 0.2
	_limb(foot, Vector3(0, -7.0, 14.0 + lift), Vector3(0, 5.5, 14.8 + lift), 9.0, coat)
	_limb(foot, Vector3(0, 6.0, 17.0 + lift), Vector3(0, 9.5, 23.5 + lift), 4.6, coat.lightened(0.04))
	_limb(foot, Vector3(0, 5.3, 19.0 + lift), Vector3(0, 8.8, 26.0 + lift), 1.8, mane)
	_limb(foot, Vector3(0, 10.2, 24.5 + lift), Vector3(0, 13.4, 20.2 + lift), 3.6, coat.lightened(0.06))
	_part(_depth(0, 11.5) + 0.05, func() -> void:
		var forehead := foot + _ground(0, 10.6) - Vector2(0, 26.4 + lift)
		_pixel(forehead + _ground(1.0, 0) - Vector2(0, 1.0), coat.darkened(0.2))
		_pixel(forehead + _ground(-1.0, 0) - Vector2(0, 1.0), coat.darkened(0.2))
		if _forward.y > -0.4:
			var face := foot + _ground(0, 12.2) - Vector2(0, 23.0 + lift)
			_line(face - Vector2(0, 2.0), face + Vector2(0, 2.0), HORSE["blaze"], 1)
		for side: float in [-1.0, 1.0]:
			var eye := foot + _ground(side * 1.6, 11.0) - Vector2(0, 24.3 + lift)
			if (_right * side).y > -0.2:
				_pixel(eye, Color(0.08, 0.06, 0.05)))
	# Tail.
	var swish := sin(TAU * t + gait) * 1.2
	_limb(foot, Vector3(swish * 0.3, -8.5, 16.0 + lift), Vector3(swish, -10.5, 8.0 + lift), 2.2, mane)
	if barded:
		# The kingdom's cloth over the body with a gold hem, and a saddle on it.
		_limb(foot, Vector3(0, -6.5, 12.6 + lift), Vector3(0, 5.0, 13.2 + lift), 9.6, _royal)
		_part(_depth(0, 5.0) + 0.02, func() -> void:
			var a := foot + _ground(0, -6.5) - Vector2(0, 8.0 + lift)
			var b := foot + _ground(0, 5.0) - Vector2(0, 8.6 + lift)
			_line(a, b, _gold, 1))
		_limb(foot, Vector3(0, -2.5, 18.6 + lift), Vector3(0, 1.5, 18.8 + lift), 4.0, C_LEATHER)
		# Reins from the bit to the rider's hands.
		_part(_depth(0, 10.0), func() -> void:
			var bit := foot + _ground(0, 13.2) - Vector2(0, 21.5 + lift)
			var hands := foot + _ground(-1.0, 5.0) - Vector2(0, 26.0 + lift)
			_line(bit, hands, C_LEATHER.darkened(0.3), 1))


## The stud farm's horses as goods (ART_SPEC §5, §8, like the pigs): a herd sheet of 4
## frames 64x64 (1, 2, 3, 4+ horses), a led horse 24x24 in 5 rows (the icon is SpriteKiln's, compose_icons.py).
func _horse_goods() -> void:
	_look = {"shirt": Color(), "legs": Color(), "hair": Color(), "tool": ""}
	var herd := Image.create_empty(64 * 4, 64, false, Image.FORMAT_RGBA8)
	var spots: Array = [[Vector2(32, 44), 2], [Vector2(20, 38), 1], [Vector2(46, 34), 3], [Vector2(28, 30), 6]]
	for frame: int in 4:
		var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		var placed: Array = spots.slice(0, frame + 1)
		placed.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
		for spot: Array in placed:
			var one := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
			_one_horse(one, spot[0], int(spot[1]), 0.62, 0.0)
			_outline(one)
			img.blend_rect(one, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
		herd.blit_rect(img, Rect2i(0, 0, 64, 64), Vector2i(frame * 64, 0))
	herd.save_png("res://assets/goods/stacks/horse.png")
	var led := Image.create_empty(24, 24 * ROWS, false, Image.FORMAT_RGBA8)
	for row: int in ROWS:
		var one := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
		_one_horse(one, Vector2(12, 21), row, 0.42, 0.0)
		_outline(one)
		led.blit_rect(one, Rect2i(0, 0, 24, 24), Vector2i(0, row * 24))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/goods/carried/animal"))
	led.save_png("res://assets/goods/carried/animal/horse.png")
	_shrink_foot = FOOT
	_scale = SCALE


## One standing horse drawn into [param img] with its hooves at [param at], facing [param dir]
## (0 = S ... 7 = SW, as the rows), shrunk by [param scale].
func _one_horse(img: Image, at: Vector2, dir: int, scale: float, swing: float) -> void:
	var angle := PI / 2.0 - dir * TAU / 8.0
	_forward = Vector2(cos(angle), sin(angle))
	_right = Vector2(-_forward.y, _forward.x)
	_shrink_foot = at
	_scale = scale
	_parts = []
	_horse(at, swing, 0.0, 0.0, false)
	_parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for part: Array in _parts:
		(part[1] as Callable).call()
	_flush(img)


# --- Drawing in body space -----------------------------------------------------------------

var _target_img: Image
var _queue: Array = []
## Shrinking around the feet (people: FOOT and SCALE; the horses of the herd: smaller).
var _shrink_foot: Vector2 = FOOT
var _scale: float = SCALE


func _ground(s: float, f: float) -> Vector2:
	var v := _right * s + _forward * f
	return Vector2(v.x, v.y * 0.5)


## Larger = nearer to the camera.
func _depth(s: float, f: float) -> float:
	var v := _right * s + _forward * f
	return v.y


func _part(depth: float, draw: Callable) -> void:
	_parts.append([depth, draw])


func _limb(foot: Vector2, a: Vector3, b: Vector3, width: float, colour: Color) -> void:
	_part(_depth((a.x + b.x) * 0.5, (a.y + b.y) * 0.5), func() -> void:
		var pa := foot + _ground(a.x, a.y) - Vector2(0, a.z)
		var pb := foot + _ground(b.x, b.y) - Vector2(0, b.z)
		_thick(pa, pb, width, colour))


func _blob(foot: Vector2, at: Vector3, radius: Vector2, colour: Color) -> void:
	_part(_depth(at.x, at.y) + 0.01, func() -> void:
		_ellipse(foot + _ground(at.x, at.y) - Vector2(0, at.z), radius, colour))


func _flush(img: Image) -> void:
	for op: Array in _queue:
		match String(op[0]):
			"px":
				var p: Vector2i = op[1]
				if Rect2i(Vector2i.ZERO, img.get_size()).has_point(p):
					img.set_pixelv(p, op[2])
	_queue = []


func _pixel(p: Vector2, colour: Color) -> void:
	_queue.append(["px", Vector2i(_shrink(p).floor()), colour])


func _shrink(p: Vector2) -> Vector2:
	return _shrink_foot + (p - _shrink_foot) * _scale


func _ellipse(centre: Vector2, radius: Vector2, colour: Color) -> void:
	for y: int in range(int(floor(centre.y - radius.y)) - 1, int(ceil(centre.y + radius.y)) + 1):
		for x: int in range(int(floor(centre.x - radius.x)) - 1, int(ceil(centre.x + radius.x)) + 1):
			var d := Vector2((x + 0.5 - centre.x) / maxf(radius.x, 0.5), (y + 0.5 - centre.y) / maxf(radius.y, 0.5))
			if d.length() <= 1.0:
				# Light from above and the front: lighter top, darker bottom edge.
				var shade := clampf(d.y * 0.14 + d.x * 0.04, -0.12, 0.16)
				_pixel(Vector2(x, y), colour.darkened(shade) if shade > 0.0 else colour.lightened(-shade))


func _thick(a: Vector2, b: Vector2, width: float, colour: Color) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b) * 2.0)))
	for s: int in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		_ellipse(p, Vector2(width * 0.5, width * 0.5), colour)


func _line(a: Vector2, b: Vector2, colour: Color, width: int) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b))))
	for s: int in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		for dx: int in width:
			for dy: int in width:
				_pixel(p + Vector2(dx - width / 2, dy - width / 2), colour)


## Selective outline: transparent pixels next to the figure get a dark version of it.
func _outline(img: Image) -> void:
	var size := img.get_size()
	var edge: Dictionary = {}
	for y: int in size.y:
		for x: int in size.x:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if Rect2i(Vector2i.ZERO, size).has_point(q) and img.get_pixelv(q).a == 0.0 and not edge.has(q):
					edge[q] = Color(c.r * 0.32, c.g * 0.27, c.b * 0.25, 1.0)
	for q: Vector2i in edge:
		img.set_pixelv(q, edge[q])
