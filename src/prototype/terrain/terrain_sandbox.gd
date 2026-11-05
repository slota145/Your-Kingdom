extends Node2D
## TERRAIN PROTOTYPE (A1): the organic ground of TerrainLayer on a hand-made coast that the
## M3 map does not have: sea with a sandy beach, a river with a ford flowing into it, a
## forest, a meadow and a dirt road with a small square. Debug texts are English and
## hardcoded (prototype-only, see CLAUDE.md).
##
## Run: godot --path . res://src/prototype/terrain/terrain_sandbox.tscn
## Controls: WASD/arrows/middle-drag pan, wheel or 1-4 zoom, O = organic on/off,
## F = grid, Esc = quit.
## Screenshot: -- --shot=<png> [--zoom=N] [--tile=X,Y] [--plain] [--frames=N]
## (--frames=N saves N shots 4 frames apart as <png>_00.png..., for an animation preview)

const MAP_SIZE := Vector2i(64, 64)
const SHOT_FRAMES := 20
const Slot := TerrainLayer.Slot

var camera: GameCamera
var terrain: TerrainLayer
var _hud: Label
var _shot_path: String = ""
var _frames: int = 0
var _shot_count: int = 1


func _ready() -> void:
	terrain = TerrainLayer.new()
	add_child(terrain)
	terrain.setup(MAP_SIZE)
	_paint_map()

	camera = GameCamera.new()
	add_child(camera)
	camera.bounds = Rect2(IsoMath.grid_to_screen(Vector2(0, MAP_SIZE.y)).x, 0,
			MAP_SIZE.x * IsoMath.HALF_W * 2.0, MAP_SIZE.y * IsoMath.HALF_H * 2.0)
	camera.position = IsoMath.tile_center_screen(Vector2i(38, 34))
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	layer.add_child(_hud)

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--zoom="):
			camera.set_zoom_index(int(arg.trim_prefix("--zoom=")))
		elif arg.begins_with("--tile="):
			var parts := arg.trim_prefix("--tile=").split(",")
			camera.position = IsoMath.tile_center_screen(Vector2i(int(parts[0]), int(parts[1])))
		elif arg == "--plain":
			terrain.organic = false
		elif arg.begins_with("--frames="):
			_shot_count = int(arg.trim_prefix("--frames="))
	_update_hud()


## Sea in the south-east behind a wavy beach, a river from the north into the sea.
func _paint_map() -> void:
	for y: int in MAP_SIZE.y:
		for x: int in MAP_SIZE.x:
			var tile := Vector2i(x, y)
			var depth := _depth(tile)
			var slot := Slot.GRASS
			if depth > 4.0:
				slot = Slot.SEA
			elif depth > -1.0:
				slot = Slot.SAND
			elif _in_ellipse(tile, Vector2(14, 16), Vector2(9, 6)):
				slot = Slot.FOREST
			elif _in_ellipse(tile, Vector2(34, 14), Vector2(7, 5)):
				slot = Slot.MEADOW
			terrain.paint(tile, slot)
	# River: meanders from the top edge down to the beach; a ford where the road crosses.
	for y: int in range(0, MAP_SIZE.y):
		var cx := 24.0 + 5.0 * sin(y * 0.22)
		for x: int in range(floori(cx - 1.0), ceili(cx + 1.2)):
			var tile := Vector2i(x, y)
			if _depth(tile) > 4.0:
				break
			terrain.paint(tile, Slot.FORD if y >= 27 and y <= 28 else Slot.WATER)
	# Dirt road from the west over the ford to a small square near the beach.
	for x: int in range(4, 44):
		var tile := Vector2i(x, 27)
		if _river_at(tile):
			continue
		terrain.paint(tile, Slot.GRASS, true)
	for y: int in range(24, 31):
		for x: int in range(40, 45):
			terrain.paint(Vector2i(x, y), Slot.GRASS, true)
	terrain.apply_paint()


func _river_at(tile: Vector2i) -> bool:
	var cx := 24.0 + 5.0 * sin(tile.y * 0.22)
	return tile.x >= floori(cx - 1.0) and tile.x < ceili(cx + 1.2)


## Tiles beyond the wavy coastline (> 4 is sea, > -1 beach).
func _depth(tile: Vector2i) -> float:
	return tile.x + tile.y - (78.0 + 4.0 * sin(tile.x * 0.35) + 3.0 * cos(tile.y * 0.27))


func _in_ellipse(tile: Vector2i, centre: Vector2, radius: Vector2) -> bool:
	var d := (Vector2(tile) - centre) / radius
	return d.length_squared() <= 1.0


func _process(_delta: float) -> void:
	if _shot_path.is_empty():
		return
	_frames += 1
	if _frames == SHOT_FRAMES:
		_hud.visible = false
	elif _frames > SHOT_FRAMES and (_frames - SHOT_FRAMES) % 4 == 0:
		var index := (_frames - SHOT_FRAMES) / 4 - 1
		var image := get_viewport().get_texture().get_image()
		if _shot_count == 1:
			image.save_png(_shot_path)
		else:
			image.save_png(_shot_path.get_basename() + "_%02d.png" % index)
		if index + 1 >= _shot_count:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_O:
			terrain.organic = not terrain.organic
		KEY_F:
			terrain.show_grid = not terrain.show_grid
		KEY_ESCAPE:
			get_tree().quit()
	_update_hud()


func _update_hud() -> void:
	_hud.text = "Terrain prototype | O organic: %s | F grid: %s" % [terrain.organic, terrain.show_grid]
