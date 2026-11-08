class_name PalisadeNode
extends Node2D
## A piece of a palisade drawn in code (M7 part 2, line model of ARCHITECTURE §6.3): a row of
## sharpened logs from a tile centre towards a neighbour (half segment), or a thicker post
## where the fence turns or ends. Positioned at its sort point (the middle of its base).

const HEIGHT := 46.0
const LOG := Color(0.55, 0.4, 0.26)
const LOG_LIT := Color(0.68, 0.52, 0.34)
const LOG_DARK := Color(0.36, 0.26, 0.17)
const OUTLINE := Color(0.18, 0.12, 0.08)
const ROPE := Color(0.32, 0.27, 0.18)
## Logs along one grid unit of fence.
const LOGS_PER_TILE := 7.0

## Ground segment in grid coordinates; a == b draws a post.
var a: Vector2
var b: Vector2
## 0 = whole, 1 = about to fall.
var damage: float = 0.0


func setup(from: Vector2, to: Vector2) -> void:
	a = from
	b = to
	var mid := IsoMath.grid_to_screen((a + b) * 0.5)
	position = Vector2(roundf(mid.x), roundf(mid.y))


func _draw() -> void:
	if a == b:
		_log(IsoMath.grid_to_screen(a) - position, 4.5, HEIGHT + 4.0, 0)
		return
	var count := maxi(roundi(a.distance_to(b) * LOGS_PER_TILE), 1)
	var points: Array[Vector2] = []
	for k: int in count:
		points.append(IsoMath.grid_to_screen(a.lerp(b, (k + 0.5) / count)) - position)
	# Back logs first (screen y), so nearer ones overlap them.
	points.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
	var i := 0
	for p: Vector2 in points:
		var h := HEIGHT - 3.0 * float(posmod(int(a.x * 13.0 + a.y * 7.0) + i, 3))
		if damage > 0.5 and (i * 5 + int(a.x * 3.0)) % 4 == 0:
			h *= 0.55   # broken logs on a battered fence
		_log(p, 3.6, h, i)
		i += 1
	# Two ropes binding the logs.
	for z: float in [HEIGHT * 0.3, HEIGHT * 0.72]:
		draw_line(IsoMath.grid_to_screen(a) - position - Vector2(0, z),
				IsoMath.grid_to_screen(b) - position - Vector2(0, z), ROPE, 1.5)


## One upright log: [param foot] its base, [param r] half its width, [param h] its height.
func _log(foot: Vector2, r: float, h: float, i: int) -> void:
	var tip := foot - Vector2(0, h + r * 1.6)
	var body := PackedVector2Array([foot + Vector2(-r, 0), foot + Vector2(r, 0),
			foot + Vector2(r, -h), tip, foot + Vector2(-r, -h)])
	draw_colored_polygon(body, LOG if i % 2 == 0 else LOG.darkened(0.06))
	# Lit left side, shaded right side.
	draw_colored_polygon(PackedVector2Array([foot + Vector2(-r, 0), foot + Vector2(-r * 0.2, 0),
			foot + Vector2(-r * 0.2, -h), tip, foot + Vector2(-r, -h)]), LOG_LIT)
	draw_line(foot + Vector2(r * 0.55, -1), foot + Vector2(r * 0.55, -h + 1), LOG_DARK)
	draw_polyline(PackedVector2Array([foot + Vector2(-r, 0), foot + Vector2(-r, -h), tip,
			foot + Vector2(r, -h), foot + Vector2(r, 0)]), OUTLINE, 1.0)
	# A knot here and there.
	if (i * 7) % 5 == 1:
		draw_circle(foot + Vector2(0, -h * 0.5), 1.0, LOG_DARK)
