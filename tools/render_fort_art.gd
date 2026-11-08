extends SceneTree
## Renders the fortification art of M7 part 2 (ART_SPEC §10.15) from the wall model and the
## PixelLab stone (assets/walls/stone, tools/make_wall_skin.gd):
##   assets/buildings/gatehouse/: base (the PixelLab gatehouse of the walls prototype with
##     battlements on top), construction_1, construction_2 (walls rising, passage open),
##   assets/buildings/tower/: base, construction_1, construction_2,
##   assets/walls/icons/: stone_wall, palisade, stairs (build menu).
## Needs a display: xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 -s res://tools/render_fort_art.gd

const OUT := "res://assets/"
## Canvas and the front (bottom) vertex of the footprint in it, per building.
const JOBS: Array[Dictionary] = [
	{"id": "gatehouse", "size": 3, "canvas": Vector2i(212, 248), "pivot": Vector2i(106, 236), "entrance": [1, 2]},
	{"id": "tower", "size": 2, "canvas": Vector2i(148, 220), "pivot": Vector2i(74, 210), "entrance": [1, 1]},
]
const ICON := Vector2i(120, 144)

var _viewport: SubViewport
var _queue: Array[Callable] = []
var _wait: int = 0
var _save_to: String = ""
var _skin: WallSkin


func _init() -> void:
	_skin = WallSkin.shared()
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	for job: Dictionary in JOBS:
		for stage: int in [0, 1, 2]:
			_queue.append(_fort.bind(job, stage))
	for stage: int in [0, 1, 2]:
		_queue.append(_workshop.bind(stage))
	for icon: String in ["stone_wall", "palisade", "stairs"]:
		_queue.append(_icon.bind(icon))


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var img := _viewport.get_texture().get_image()
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_to.get_base_dir()))
			img.save_png(ProjectSettings.globalize_path(_save_to))
			print("saved ", _save_to)
		return false
	if _queue.is_empty():
		return true
	for child: Node in _viewport.get_children():
		child.queue_free()
	(_queue.pop_front() as Callable).call()
	_wait = 4
	return false


func _world(canvas: Vector2i, focus_screen: Vector2) -> Node2D:
	_viewport.size = canvas
	var world := Node2D.new()
	world.y_sort_enabled = true
	_viewport.add_child(world)
	var cam := Camera2D.new()
	cam.position = focus_screen
	_viewport.add_child(cam)
	cam.make_current()
	return world


## Stage 0 = finished, 1 and 2 = construction phases.
func _fort(job: Dictionary, stage: int) -> void:
	var size: int = job["size"]
	var canvas: Vector2i = job["canvas"]
	var pivot: Vector2i = job["pivot"]
	var front := IsoMath.grid_to_screen(Vector2(size, size))
	var world := _world(canvas, front - Vector2(pivot) + Vector2(canvas) / 2.0)
	var model := BlockWallModel.new()
	var gate: bool = job["id"] == "gatehouse"
	if gate:
		model.add_gatehouse(Vector2i.ZERO, Vector2i(0, 1))
	else:
		model.add_tower(Vector2i.ZERO, size)
	var name := "base"
	if stage > 0:
		model.fort_scale = 0.3 if stage == 1 else 0.62
		model.battlements = false
		name = "construction_%d" % stage
	if gate and stage == 0:
		# The PixelLab gatehouse body (prototype repaint), battlements of the model on top.
		var body := Sprite2D.new()
		body.texture = load(WallSkin.DIR + "gatehouse_body.png") as Texture2D
		body.centered = false
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WallSkin.DIR + "skin.json"))
		body.position = front - Vector2(meta["gatehouse_pivot"][0], meta["gatehouse_pivot"][1])
		body.z_index = -2
		world.add_child(body)
		for piece: BlockWallModel.Piece in model.build():
			if piece.kind == &"merlon" or piece.kind == &"parapet":
				var node := WallPieceNode.new()
				node.setup(piece, _skin)
				world.add_child(node)
			elif piece.kind == &"gh_side" and piece.tile.x == 2:
				# The repaint has a stub of wall on this side: drawn over with the stone.
				var side := WallPieceNode.new()
				side.setup(piece, _skin)
				side.right_faces_only = true
				side.z_index = -1
				world.add_child(side)
	else:
		for piece: BlockWallModel.Piece in model.build():
			var node := WallPieceNode.new()
			node.setup(piece, _skin)
			world.add_child(node)
		if stage > 0:
			world.add_child(_Scaffold.new(size, model.height * (model.fort_scale + 0.35) + (BlockWallModel.GATEHOUSE_EXTRA if gate else BlockWallModel.TOWER_EXTRA) * 0.3))
	_save_to = OUT + "buildings/%s/%s.png" % [job["id"], name]
	var json := {"footprint": [size, size], "entrance": job["entrance"], "pivot": [pivot.x, pivot.y]}
	var file := FileAccess.open(OUT + "buildings/%s/%s.json" % [job["id"], name], FileAccess.WRITE)
	if file == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "buildings/" + job["id"]))
		file = FileAccess.open(OUT + "buildings/%s/%s.json" % [job["id"], name], FileAccess.WRITE)
	file.store_string(JSON.stringify(json, "\t"))
	file.close()


func _icon(what: String) -> void:
	var world := _world(ICON, IsoMath.grid_to_screen(Vector2(1.0, 1.5)) - Vector2(0, 42))
	match what:
		"stone_wall":
			var model := BlockWallModel.new()
			for t: Vector2i in [Vector2i(0, 1), Vector2i(1, 1)]:
				model.walls[t] = false
			for piece: BlockWallModel.Piece in model.build():
				var node := WallPieceNode.new()
				node.setup(piece, _skin)
				world.add_child(node)
		"palisade":
			for t: Vector2i in [Vector2i(0, 1), Vector2i(1, 1)]:
				var c := IsoMath.tile_center(t)
				for d: Vector2 in [Vector2(-0.5, 0), Vector2(0.5, 0)]:
					var node := PalisadeNode.new()
					node.setup(c, c + d)
					world.add_child(node)
		"stairs":
			var model := BlockWallModel.new()
			for t: Vector2i in [Vector2i(0, 1), Vector2i(1, 1)]:
				model.walls[t] = false
			for piece: BlockWallModel.Piece in model.build():
				var node := WallPieceNode.new()
				node.setup(piece, _skin)
				world.add_child(node)
			var stairs := StairsNode.new()
			stairs.setup(Vector2i(0, 2), Vector2i(0, -1), _skin)
			world.add_child(stairs)
	_save_to = OUT + "walls/icons/%s.png" % what


## The siege workshop (3x3, door on the +x side): an open timber shed with a shingled roof,
## a ram frame being put together under it, planks and a ladder by the wall.
func _workshop(stage: int) -> void:
	var canvas := Vector2i(212, 200)
	var pivot := Vector2i(106, 188)
	var front := IsoMath.grid_to_screen(Vector2(3, 3))
	var world := _world(canvas, front - Vector2(pivot) + Vector2(canvas) / 2.0)
	var node := _Workshop.new()
	node.stage = stage
	world.add_child(node)
	var name := "base" if stage == 0 else "construction_%d" % stage
	_save_to = OUT + "buildings/siege_workshop/%s.png" % name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "buildings/siege_workshop"))
	var file := FileAccess.open(OUT + "buildings/siege_workshop/%s.json" % name, FileAccess.WRITE)
	file.store_string(JSON.stringify({"footprint": [3, 3], "entrance": [2, 1], "pivot": [pivot.x, pivot.y]}, "\t"))
	file.close()


class _Workshop:
	extends Node2D
	const POST := Color(0.42, 0.29, 0.17)
	const POST_LIT := Color(0.58, 0.42, 0.26)
	const ROOF := Color(0.45, 0.33, 0.24)
	const ROOF_DARK := Color(0.33, 0.23, 0.16)
	const PLANK := Color(0.7, 0.55, 0.36)
	const OUTLINE := Color(0.16, 0.11, 0.07)
	const GROUND := Color(0.48, 0.42, 0.32)
	var stage: int = 0

	func _p(x: float, y: float, z: float) -> Vector2:
		return IsoMath.grid_to_screen(Vector2(x, y)) - Vector2(0, z)

	func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, fill: Color) -> void:
		var poly := PackedVector2Array([a, b, c, d])
		draw_colored_polygon(poly, fill)
		draw_polyline(poly + PackedVector2Array([a]), OUTLINE, 1.0)

	func _post(x: float, y: float, h: float) -> void:
		var a := _p(x, y, 0)
		draw_line(a, a - Vector2(0, h), OUTLINE, 5.0)
		draw_line(a, a - Vector2(0, h), POST, 3.0)
		draw_line(a + Vector2(-1, 0), a - Vector2(1, h), POST_LIT, 1.0)

	func _draw() -> void:
		# Trodden ground with wood chips.
		_quad(_p(0.15, 0.15, 0), _p(2.85, 0.15, 0), _p(2.85, 2.85, 0), _p(0.15, 2.85, 0), GROUND)
		for k: int in 18:
			var g := Vector2(0.4 + fmod(k * 0.61, 2.2), 0.4 + fmod(k * 0.37, 2.2))
			draw_rect(Rect2(_p(g.x, g.y, 0), Vector2(2, 1)), PLANK.darkened(0.1))
		var eave := 38.0
		var ridge := 62.0
		# A stack of planks at the back and a ladder leaning on the back posts.
		for k: int in 4:
			_quad(_p(0.3, 0.4, 3 * k), _p(1.6, 0.4, 3 * k), _p(1.6, 0.8, 3 * k + 3), _p(0.3, 0.8, 3 * k + 3),
					PLANK.darkened(0.06 * k))
		for side: float in [0.0, 0.18]:
			draw_line(_p(2.3 + side, 0.3, 0), _p(2.5 + side, 0.3, 46), POST, 2.0)
		for k: int in 6:
			var t := (k + 0.5) / 6.0
			draw_line(_p(2.3 + 0.2 * t, 0.3, 46 * t), _p(2.48 + 0.2 * t, 0.3, 46 * t), PLANK, 1.0)
		# The ram frame under construction: sills, uprights and the log on trestles.
		var r := [Vector2(0.9, 1.2), Vector2(2.2, 1.2), Vector2(2.2, 1.9), Vector2(0.9, 1.9)]
		for k: int in 4:
			var a := _p(r[k].x, r[k].y, 4)
			var b := _p(r[(k + 1) % 4].x, r[(k + 1) % 4].y, 4)
			draw_line(a, b, POST, 3.0)
			draw_line(a, a - Vector2(0, 18), POST, 2.0)
		draw_line(_p(0.8, 1.55, 12), _p(2.4, 1.55, 12), POST.darkened(0.2), 6.0)
		draw_line(_p(0.8, 1.55, 12), _p(2.4, 1.55, 12), PLANK.darkened(0.15), 4.0)
		draw_line(_p(2.35, 1.55, 12), _p(2.5, 1.55, 12), Color(0.35, 0.35, 0.38), 7.0)
		if stage == 1:
			for x: float in [0.25, 2.75]:
				for y: float in [0.25, 2.75]:
					_post(x, y, eave * 0.6)
			return
		# Posts and the roof (half the shingles while it is being built).
		for x: float in [0.25, 1.5, 2.75]:
			for y: float in [0.25, 2.75]:
				_post(x, y, eave)
		var l0 := _p(0.1, 0.1, eave)
		var l1 := _p(2.9, 0.1, eave)
		var r0 := _p(0.1, 2.9, eave)
		var r1 := _p(2.9, 2.9, eave)
		var k0 := _p(0.1, 1.5, ridge)
		var k1 := _p(2.9, 1.5, ridge)
		var share := 1.0 if stage == 0 else 0.5
		_quad(l0, l1, k1, k0, ROOF_DARK)
		var rr1 := r0.lerp(r1, share)
		var kk1 := k0.lerp(k1, share)
		_quad(r0, rr1, kk1, k0, ROOF)
		for k: int in range(1, 6):
			var t := k / 6.0
			draw_line(r0.lerp(k0, t), rr1.lerp(kk1, t), ROOF.darkened(0.2), 1.0)
		for k: int in range(1, 12):
			var t := k / 12.0 * share
			draw_line(r0.lerp(r1, t), k0.lerp(k1, t), ROOF.darkened(0.12), 1.0)
		if stage == 2:
			for k: int in range(6, 12):
				var t := k / 12.0
				draw_line(r0.lerp(r1, t), k0.lerp(k1, t), POST, 2.0)   # bare rafters
		# Gable end at +x with crossed beams.
		var g := PackedVector2Array([_p(2.9, 0.1, eave), _p(2.9, 2.9, eave), _p(2.9, 1.5, ridge)])
		draw_colored_polygon(g, POST_LIT.darkened(0.15))
		draw_polyline(g + PackedVector2Array([g[0]]), OUTLINE, 1.0)
		draw_line(_p(2.9, 0.5, eave + 3), _p(2.9, 2.5, eave + 3), POST, 2.0)


## Wooden scaffolding poles around a fort under construction.
class _Scaffold:
	extends Node2D
	var size: int
	var top: float

	func _init(footprint: int, height: float) -> void:
		size = footprint
		top = height
		var s := IsoMath.grid_to_screen(Vector2(size, size))
		position = s + Vector2(0, 2)
		z_index = 1

	func _draw() -> void:
		var wood := Color(0.55, 0.4, 0.25)
		var dark := Color(0.3, 0.21, 0.13)
		var n := size
		var corners: Array[Vector2] = [Vector2(0, n), Vector2(n, n), Vector2(n, 0)]
		var feet: Array[Vector2] = []
		for i: int in 2:
			for k: int in n * 2 + 1:
				var g: Vector2 = corners[i].lerp(corners[i + 1], float(k) / (n * 2))
				g += (g - Vector2(n, n) * 0.5).normalized() * 0.12
				feet.append(IsoMath.grid_to_screen(g) - position - Vector2(0, -2))
		for f: Vector2 in feet:
			draw_line(f, f - Vector2(0, top), dark, 2.0)
			draw_line(f + Vector2(-1, 0), f - Vector2(1, top), wood, 1.0)
		for z: float in [top * 0.4, top * 0.8]:
			for k: int in feet.size() - 1:
				if k == n * 2:
					continue
				draw_line(feet[k] - Vector2(0, z), feet[k + 1] - Vector2(0, z), wood, 2.0)
