extends Node2D
## ORGANIC GRASS PROTOTYPE (A1): grass without a visible tile grid. All tiles draw one base
## texture; a shader swaps in lighter and darker grass in soft world-space patches, and
## flower decals are scattered off-grid. Self-contained on purpose: the real TerrainLayer
## is being changed by M3, so nothing here touches target code. Debug texts are English
## and hardcoded (prototype-only, see CLAUDE.md).
##
## Run: godot --path . res://src/prototype/terrain/grass_sandbox.tscn
## Controls: WASD/arrows/middle-drag pan, wheel or 1-4 zoom, O = organic on/off,
## D = decals on/off, F = grid, Esc = quit.
## Screenshot: -- --shot=<png> [--zoom=N] [--plain]

const MAP_SIZE := Vector2i(48, 48)
const CHUNK := 16
const GRASS_DIR := "res://assets/terrain/grass/"
const DECOR_DIR := "res://assets/terrain/grass_decor/"
const DECOR_NAMES: PackedStringArray = ["flowers_white", "flowers_yellow", "flowers_purple", "clover"]
## Chance that a tile gets a decal; the decal sits at a random offset, not on the tile centre.
const DECOR_CHANCE := 0.06
const SHOT_FRAMES := 20

var camera: GameCamera
var show_grid: bool = false
var show_decor: bool = true
var _base: Texture2D
var _grid: Texture2D
var _decor: Array[Texture2D] = []
var _material: ShaderMaterial
var _organic: bool = true
var _tile_chunks: Array[_Tiles] = []
var _decor_chunks: Array[_Decor] = []
var _hud: Label
var _shot_path: String = ""
var _frames: int = 0


class _Tiles:
	extends Node2D
	var base: Texture2D
	var grid: Texture2D
	var show_grid: bool = false
	var tiles: Rect2i

	func _draw() -> void:
		var origin := Vector2(IsoMath.TILE_SIZE.x / 2.0, 0.0)
		for y: int in range(tiles.position.y, tiles.end.y):
			for x: int in range(tiles.position.x, tiles.end.x):
				var top := IsoMath.grid_to_screen(Vector2(x, y)) - origin
				draw_texture(base, top)
				if show_grid:
					draw_texture(grid, top)


## Decals live in their own chunks above all tile chunks, so a decal crossing a chunk border
## is never covered by the neighbouring chunk's tiles.
class _Decor:
	extends Node2D
	var decor: Array[Texture2D] = []
	var visible_decor: bool = true
	var tiles: Rect2i

	func _draw() -> void:
		if not visible_decor:
			return
		for y: int in range(tiles.position.y, tiles.end.y):
			for x: int in range(tiles.position.x, tiles.end.x):
				var h := _hash(x, y)
				if h % 1000 >= int(DECOR_CHANCE * 1000.0):
					continue
				var tex: Texture2D = decor[(h / 1000) % decor.size()]
				# Random point inside the tile diamond, in tile units (-0.4..0.4 each axis).
				var offset := Vector2(((h >> 12) % 81 - 40) / 100.0, ((h >> 20) % 81 - 40) / 100.0)
				var centre := IsoMath.grid_to_screen(Vector2(x + 0.5, y + 0.5) + offset)
				draw_texture(tex, (centre - tex.get_size() / 2.0).round())

	static func _hash(x: int, y: int) -> int:
		var h := (x * 73856093) ^ (y * 19349663)
		h = (h ^ (h >> 13)) * 1274126177
		return absi(h ^ (h >> 16))


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
	_base = load(GRASS_DIR + "a.png") as Texture2D
	_grid = ArtPaths.texture("terrain/grid/a.png")
	for name: String in DECOR_NAMES:
		_decor.append(load(DECOR_DIR + name + ".png") as Texture2D)
	_material = ShaderMaterial.new()
	_material.shader = load("res://src/prototype/terrain/organic_ground.gdshader") as Shader
	_material.set_shader_parameter("light_tex", load(GRASS_DIR + "light.png"))
	_material.set_shader_parameter("dark_tex", load(GRASS_DIR + "dark.png"))
	_build_chunks()

	camera = GameCamera.new()
	add_child(camera)
	camera.bounds = Rect2(IsoMath.grid_to_screen(Vector2(0, MAP_SIZE.y)).x, 0,
			MAP_SIZE.x * IsoMath.HALF_W * 2.0, MAP_SIZE.y * IsoMath.HALF_H * 2.0)
	camera.position = IsoMath.grid_to_screen(Vector2(MAP_SIZE) / 2.0)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	layer.add_child(_hud)

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--zoom="):
			camera.set_zoom_index(int(arg.trim_prefix("--zoom=")))
		elif arg == "--plain":
			_set_organic(false)
	_update_hud()


func _build_chunks() -> void:
	var bounds := Rect2i(Vector2i.ZERO, MAP_SIZE)
	for pass_index: int in 2:
		for cy: int in ceili(MAP_SIZE.y / float(CHUNK)):
			for cx: int in ceili(MAP_SIZE.x / float(CHUNK)):
				var rect := Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK).intersection(bounds)
				if pass_index == 0:
					var tiles := _Tiles.new()
					tiles.base = _base
					tiles.grid = _grid
					tiles.tiles = rect
					tiles.material = _material
					add_child(tiles)
					_tile_chunks.append(tiles)
				else:
					var decor := _Decor.new()
					decor.decor = _decor
					decor.tiles = rect
					add_child(decor)
					_decor_chunks.append(decor)


func _process(_delta: float) -> void:
	if _shot_path.is_empty():
		return
	_frames += 1
	if _frames == SHOT_FRAMES:
		_hud.visible = false
	elif _frames == SHOT_FRAMES + 2:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_O:
			_set_organic(not _organic)
		KEY_D:
			show_decor = not show_decor
			for chunk: _Decor in _decor_chunks:
				chunk.visible_decor = show_decor
				chunk.queue_redraw()
		KEY_F:
			show_grid = not show_grid
			for chunk: _Tiles in _tile_chunks:
				chunk.show_grid = show_grid
				chunk.queue_redraw()
		KEY_ESCAPE:
			get_tree().quit()
	_update_hud()


func _set_organic(value: bool) -> void:
	_organic = value
	_material.set_shader_parameter("enabled", value)


func _update_hud() -> void:
	_hud.text = "Organic grass prototype | O organic: %s | D decals: %s | F grid: %s" % [
		_organic, show_decor, show_grid]
