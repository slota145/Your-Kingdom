extends Node
## TERRAIN SCREENSHOTS (prototype): starts the real game scene, optionally lays a road and a
## small square, moves the camera and saves a screenshot. For checking ground art in the cloud.
##
## Run: godot --path . res://src/prototype/terrain/game_shot.tscn -- --shot=<png>
##      [--tile=X,Y] [--zoom=N] [--roads] [--plain]

const GAME_SCENE := "res://src/main/game_scene.tscn"
const SETTLE_FRAMES := 10
const SHOT_FRAMES := 30

var _game: Node2D
var _frames: int = 0
var _shot_path: String = ""
var _tile: Vector2i = Vector2i(-1, -1)
var _zoom: int = 1
var _roads: bool = false
var _plain: bool = false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--tile="):
			var parts := arg.trim_prefix("--tile=").split(",")
			_tile = Vector2i(int(parts[0]), int(parts[1]))
		elif arg.begins_with("--zoom="):
			_zoom = int(arg.trim_prefix("--zoom="))
		elif arg == "--roads":
			_roads = true
		elif arg == "--plain":
			_plain = true
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as Node2D
	add_child(_game)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == SETTLE_FRAMES:
		_arrange()
	elif _frames == SHOT_FRAMES and not _shot_path.is_empty():
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _arrange() -> void:
	var sim: Simulation = _game.get("sim")
	var camera: GameCamera = _game.get("camera")
	var view: ProvinceView = _game.get("view")
	view.terrain.organic = not _plain
	if _tile.x >= 0:
		camera.position = IsoMath.tile_center_screen(_tile)
	camera.set_zoom_index(_zoom)
	if _roads:
		var centre := _tile if _tile.x >= 0 else sim.province.grid.size / 2
		var tiles: Array[Vector2i] = []
		for i: int in range(-9, 4):
			tiles.append(centre + Vector2i(i, 2))
		for i: int in range(-6, 3):
			tiles.append(centre + Vector2i(-4, i))
		for y: int in range(-1, 3):
			for x: int in range(3, 7):
				tiles.append(centre + Vector2i(x, y))
		sim.execute(BuildRoadCommand.new(tiles))
		for tile: Vector2i in tiles:
			view.terrain.refresh_tile(tile)
