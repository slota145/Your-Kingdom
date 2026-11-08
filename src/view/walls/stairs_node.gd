class_name StairsNode
extends Node2D
## Stone stairs leaning against a wall (M7 part 2), drawn in code: a ramp of steps rising
## across its tile from the far edge (ground) to the wall (wall height), with a solid side.
## Positioned at the tile's sort point.

const STEPS := 7
const WIDTH := 0.62
const STONE := Color(0.64, 0.6, 0.53)
const OUTLINE := Color(0.25, 0.22, 0.19)

var tile: Vector2i
## Grid step from the stairs to the wall they climb.
var up: Vector2i
var height: float = BlockWallModel.HEIGHT
var tint: Color = STONE


func setup(at: Vector2i, towards: Vector2i, wall_skin: WallSkin) -> void:
	tile = at
	up = towards
	if wall_skin != null:
		tint = wall_skin.merlon_color.lerp(STONE, 0.4)
	var s := IsoMath.tile_center_screen(tile)
	position = Vector2(roundf(s.x), roundf(s.y))


func _draw() -> void:
	var c := IsoMath.tile_center(tile)
	var along := Vector2(up)
	var across := Vector2(up.y, up.x)
	var p := func(u: float, v: float, z: float) -> Vector2:
		return IsoMath.grid_to_screen(c + across * u + along * v) - position - Vector2(0, z)
	var w := WIDTH * 0.5
	# Treads and risers from the back of the screen to the front.
	var order: Array[int] = []
	for k: int in STEPS:
		order.append(k)
	var toward_camera := along.dot(Vector2(1, 1)) > 0.0
	if not toward_camera:
		order.reverse()
	for k: int in order:
		var v0 := -0.5 + float(k) / STEPS
		var v1 := -0.5 + float(k + 1) / STEPS
		var z := height * float(k + 1) / STEPS
		var zb := height * float(k) / STEPS
		var tread := PackedVector2Array([p.call(-w, v0, z), p.call(w, v0, z), p.call(w, v1, z), p.call(-w, v1, z)])
		draw_colored_polygon(tread, tint.lightened(0.12))
		draw_polyline(tread + PackedVector2Array([tread[0]]), OUTLINE, 1.0)
		# The riser at the low edge of the tread faces the camera when the stairs climb away.
		if not toward_camera:
			var riser := PackedVector2Array([p.call(-w, v0, zb), p.call(w, v0, zb), p.call(w, v0, z), p.call(-w, v0, z)])
			draw_colored_polygon(riser, tint.darkened(0.12))
			draw_polyline(riser + PackedVector2Array([riser[0]]), OUTLINE, 1.0)
	# The solid side under the steps that faces the camera.
	var side_u := w if across.dot(Vector2(1, 1)) > 0.0 else -w
	var side := PackedVector2Array([p.call(side_u, -0.5, 0.0)])
	for k: int in STEPS:
		side.append(p.call(side_u, -0.5 + float(k) / STEPS, height * float(k + 1) / STEPS))
		side.append(p.call(side_u, -0.5 + float(k + 1) / STEPS, height * float(k + 1) / STEPS))
	side.append(p.call(side_u, 0.5, 0.0))
	draw_colored_polygon(side, tint.darkened(0.25))
	draw_polyline(side + PackedVector2Array([side[0]]), OUTLINE, 1.0)
	# Courses of stone on the side.
	for z: float in [height * 0.25, height * 0.5, height * 0.75]:
		var v := -0.5 + z / height - 0.5 / STEPS
		draw_line(p.call(side_u, v, z), p.call(side_u, 0.5, z), tint.darkened(0.38))
