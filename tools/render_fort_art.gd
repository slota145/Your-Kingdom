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
