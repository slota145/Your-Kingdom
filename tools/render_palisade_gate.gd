extends SceneTree
## Renders the palisade gate (M7 part 3, owner's request; ART_SPEC §10.16) in code, in the
## style of the palisade (PalisadeNode): two tall squared posts with a small shingled roof on a
## lintel and two plank leaves with iron bands, closed. 1x1 footprint, the fence along grid y
## through the tile centre, the doors facing +x (the turned gate is the mirror).
##   assets/buildings/palisade_gate/: base, construction_1 (two short posts), construction_2
##   (the posts and the lintel, no leaves yet).
## Needs a display: xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 -s res://tools/render_palisade_gate.gd

const OUT := "res://assets/buildings/palisade_gate/"
const CANVAS := Vector2i(96, 136)
## The front vertex of the footprint (grid 1,1) in the canvas.
const PIVOT := Vector2i(48, 126)

var _viewport: SubViewport
var _stage: int = 0
var _wait: int = 0


func _init() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = CANVAS
	root.add_child(_viewport)
	_draw_stage()


func _draw_stage() -> void:
	for child: Node in _viewport.get_children():
		child.queue_free()
	var cam := Camera2D.new()
	cam.position = IsoMath.grid_to_screen(Vector2(1, 1)) - Vector2(PIVOT) + Vector2(CANVAS) / 2.0
	_viewport.add_child(cam)
	cam.make_current()
	var gate := _Gate.new()
	gate.stage = _stage
	_viewport.add_child(gate)
	_wait = 4


func _process(_delta: float) -> bool:
	_wait -= 1
	if _wait > 0:
		return false
	var name := "base" if _stage == 0 else "construction_%d" % _stage
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	var file := FileAccess.open(OUT + name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"footprint": [1, 1], "entrance": [0, 0], "pivot": [PIVOT.x, PIVOT.y]}, "\t"))
	file.close()
	print("saved ", name)
	_stage += 1
	if _stage > 2:
		return true
	_draw_stage()
	return false


class _Gate:
	extends Node2D
	const POST := Color(0.47, 0.33, 0.2)
	const POST_LIT := Color(0.64, 0.48, 0.3)
	const POST_DARK := Color(0.33, 0.23, 0.14)
	const PLANK := Color(0.56, 0.4, 0.25)
	const PLANK_DARK := Color(0.43, 0.3, 0.18)
	const IRON := Color(0.27, 0.27, 0.29)
	const IRON_LIT := Color(0.5, 0.5, 0.52)
	const ROOF := Color(0.42, 0.3, 0.21)
	const ROOF_LIT := Color(0.55, 0.4, 0.28)
	const OUTLINE := Color(0.16, 0.11, 0.07)
	const X := 0.5
	const POST_H := 66.0
	const LEAF_H := 46.0
	var stage: int = 0

	func _p(y: float, z: float, x: float = X) -> Vector2:
		return IsoMath.grid_to_screen(Vector2(x, y)) - Vector2(0, z)

	func _poly(points: Array, fill: Color) -> void:
		var poly := PackedVector2Array(points)
		draw_colored_polygon(poly, fill)
		poly.append(points[0])
		draw_polyline(poly, OUTLINE, 1.0)

	## A squared post standing on grid point (X, y): its front (+x) and left (+y) faces.
	func _post(y: float, h: float) -> void:
		var r := 0.09
		var a := _p(y - r, 0, X + r)
		var b := _p(y + r, 0, X + r)
		var c := _p(y + r, 0, X - r)
		# +y face (towards the screen's lower left: lit).
		_poly([b, c, c - Vector2(0, h), b - Vector2(0, h)], POST_LIT)
		# +x face (lower right: in shade).
		_poly([a, b, b - Vector2(0, h), a - Vector2(0, h)], POST)
		# The top, cut flat with a little cap.
		var top := [_p(y - r, h, X + r), _p(y + r, h, X + r), _p(y + r, h, X - r), _p(y - r, h, X - r)]
		_poly(top, POST_DARK)
		draw_line(a - Vector2(0, h * 0.5), a - Vector2(0, h * 0.5 - 2), POST_DARK, 1.0)

	func _draw() -> void:
		if stage == 1:
			_post(0.04, POST_H * 0.55)
			_post(0.96, POST_H * 0.55)
			return
		_post(0.04, POST_H)
		if stage == 0:
			_leaves()
		_post(0.96, POST_H)
		# The lintel between the posts.
		var l0 := _p(-0.08, POST_H - 6)
		var l1 := _p(1.08, POST_H - 6)
		_poly([l0, l1, l1 - Vector2(0, 7), l0 - Vector2(0, 7)], POST)
		draw_line(l0 - Vector2(0, 7), l1 - Vector2(0, 7), POST_LIT, 1.0)
		if stage != 0:
			return
		# A small pent roof of shingles over it, sloping both ways along the fence.
		var e := 0.22
		var ridge := POST_H + 10.0
		var front := [_p(-0.14, POST_H - 1, X + e), _p(1.14, POST_H - 1, X + e), _p(1.14, ridge, X), _p(-0.14, ridge, X)]
		var back := [_p(-0.14, ridge, X), _p(1.14, ridge, X), _p(1.14, POST_H - 1, X - e), _p(-0.14, POST_H - 1, X - e)]
		_poly(back, ROOF)
		_poly(front, ROOF_LIT)
		for k: int in range(1, 6):
			var t := k / 6.0
			draw_line(_p(-0.14 + 1.28 * t, POST_H - 1, X + e), _p(-0.14 + 1.28 * t, ridge, X), ROOF.darkened(0.15), 1.0)
		draw_line(_p(-0.14, POST_H + 4, X + e * 0.55), _p(1.14, POST_H + 4, X + e * 0.55), ROOF.darkened(0.2), 1.0)

	## Two leaves of upright planks between the posts, iron bands and a brace, closed.
	func _leaves() -> void:
		for leaf: int in 2:
			var y0 := 0.12 if leaf == 0 else 0.51
			var y1 := 0.49 if leaf == 0 else 0.88
			var top := LEAF_H + (3.0 if leaf == 0 else 0.0)
			_poly([_p(y0, 2), _p(y1, 2), _p(y1, LEAF_H), _p(y0, top)], PLANK)
			for k: int in range(1, 5):
				var y := lerpf(y0, y1, k / 5.0)
				draw_line(_p(y, 3), _p(y, LEAF_H - 1), PLANK_DARK, 1.0)
			# Sharpened plank tops.
			for k: int in 5:
				var y := lerpf(y0, y1, (k + 0.5) / 5.0)
				var h := lerpf(top, LEAF_H, (k + 0.5) / 5.0)
				_poly([_p(y - 0.035, h), _p(y + 0.035, h), _p(y, h + 5)], PLANK)
			# Iron bands and a diagonal brace.
			for z: float in [10.0, 34.0]:
				draw_line(_p(y0 + 0.01, z), _p(y1 - 0.01, z), IRON, 2.0)
				draw_line(_p(y0 + 0.01, z + 1), _p(y1 - 0.01, z + 1), IRON_LIT, 1.0)
			draw_line(_p(y0 + 0.02, 12), _p(y1 - 0.02, 32), PLANK_DARK.darkened(0.2), 2.0)
			# The ring handle at the meeting edge.
			var ring_at := _p(0.47 if leaf == 0 else 0.55, 22)
			draw_arc(ring_at, 2.0, 0.0, TAU, 8, IRON, 1.0)
		draw_line(_p(0.5, 2), _p(0.5, LEAF_H), OUTLINE, 1.0)
