extends Node
## M4A SCREENSHOTS (prototype): plays the start map with the automatic player (SliceBot) for
## a while, opens the result in the real game scene, selects a building and saves a
## screenshot. For checking the new buildings and panels in the cloud.
##
## Run: godot --path . res://src/prototype/m4a/town_shot.tscn -- --shot=<png>
##      [--minutes=N] [--select=<building id>] [--zoom=N] [--layout] [--focus=<block>] [--stocks] [--hide_build] [--moods]
##
## --layout (M4b-1.5) adds a street quarter next to the bot's town: burgher and patrician
## houses in a straight row, rows meeting at corners and two rows back to back, each facing
## its road. --focus centres the camera on one block (row, corner, back, patrician_back,
## burgher_corner) or the whole quarter (all).

const GAME_SCENE := "res://src/main/game_scene.tscn"
const SAVE_PATH := "user://m4a_shot.sav"
const SETTLE_FRAMES := 10
const SHOT_FRAMES := 40

var _game: Node2D
## UI-2: a road tool in hand behind the first house of [member _select] (see-through buildings).
var _behind: bool = false
var _frames: int = 0
var _shot_path: String = ""
var _select: StringName = &""
## --moods (E2 part 3): faces over every house, as with the "Contentment" button.
var _moods: bool = false
var _zoom: int = 1
var _layout: bool = false
var _focus: String = "all"
## --stocks (M4b-2): open the "Kingdom stocks" window.
var _stocks: bool = false
## --hide_build (2026-11-07): the build bar hidden, the "Build" button in its place.
var _hide_build: bool = false
## Block name -> grid point the camera looks at (set by _add_quarter).
var _blocks: Dictionary[String, Vector2] = {}

## The quarter (offsets from its origin): [house origin, orientation, level].
const QUARTER: Array = [
	# Straight burgher row facing +y, road in front.
	[Vector2i(0, 0), 1, 2], [Vector2i(2, 0), 1, 2], [Vector2i(4, 0), 1, 2], [Vector2i(6, 0), 1, 2],
	# Patrician corner: a row facing +x meets a row facing +y.
	[Vector2i(14, 0), 0, 3], [Vector2i(14, 2), 0, 3], [Vector2i(14, 4), 0, 3],
	[Vector2i(10, 4), 1, 3], [Vector2i(12, 4), 1, 3],
	# Burgher rows back to back along y.
	[Vector2i(21, 0), 2, 2], [Vector2i(21, 2), 2, 2], [Vector2i(21, 4), 2, 2],
	[Vector2i(23, 0), 0, 2], [Vector2i(23, 2), 0, 2], [Vector2i(23, 4), 0, 2],
	# Patrician rows back to back along x.
	[Vector2i(0, 9), 3, 3], [Vector2i(2, 9), 3, 3], [Vector2i(4, 9), 3, 3],
	[Vector2i(0, 11), 1, 3], [Vector2i(2, 11), 1, 3], [Vector2i(4, 11), 1, 3],
	# Burgher corner.
	[Vector2i(14, 9), 0, 2], [Vector2i(14, 11), 0, 2], [Vector2i(14, 13), 0, 2],
	[Vector2i(10, 13), 1, 2], [Vector2i(12, 13), 1, 2],
]
## Road lines of the quarter: [from, to] (inclusive, offsets).
const QUARTER_ROADS: Array = [
	[Vector2i(-1, 2), Vector2i(8, 2)], [Vector2i(8, -1), Vector2i(8, 1)],
	[Vector2i(16, -1), Vector2i(16, 7)], [Vector2i(9, 6), Vector2i(15, 6)],
	[Vector2i(20, -1), Vector2i(20, 6)], [Vector2i(25, -1), Vector2i(25, 6)],
	[Vector2i(-1, 8), Vector2i(6, 8)], [Vector2i(-1, 13), Vector2i(6, 13)],
	[Vector2i(16, 8), Vector2i(16, 16)], [Vector2i(9, 15), Vector2i(15, 15)],
]


func _ready() -> void:
	var minutes := 40
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--minutes="):
			minutes = int(arg.trim_prefix("--minutes="))
		elif arg.begins_with("--select="):
			_select = StringName(arg.trim_prefix("--select="))
		elif arg.begins_with("--zoom="):
			_zoom = int(arg.trim_prefix("--zoom="))
		elif arg == "--layout":
			_layout = true
		elif arg == "--stocks":
			_stocks = true
		elif arg == "--moods":
			_moods = true
		elif arg == "--behind":
			_behind = true
		elif arg == "--hide_build":
			_hide_build = true
		elif arg.begins_with("--focus="):
			_focus = arg.trim_prefix("--focus=")
	var sim := Simulation.from_map(Data.registry, Data.registry.get_map(&"riverlands"))
	SliceBot.new(sim).run(minutes * 60)
	if _layout:
		_add_quarter(sim)
	SaveService.save_simulation(SAVE_PATH, sim)
	Game.start_request = {"load": SAVE_PATH}
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as Node2D
	add_child(_game)
	Game.paused = true


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
	camera.set_zoom_index(_zoom)
	if _stocks:
		_game.call("_toggle_stocks")
	if _hide_build:
		_game.call("_show_build_menu", false)
	if _moods:
		(_game.get("view") as ProvinceView).moods.show_all = true
	if _layout and _blocks.has(_focus):
		camera.position = IsoMath.grid_to_screen(_blocks[_focus])
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == _select and _behind:
			# The cursor on the tile just behind the house, a road tool in hand.
			var tile := b.origin - Vector2i(1, 0)
			camera.position = IsoMath.tile_center_screen(tile)
			_game.call("_set_tool", {"kind": &"road"})
			_warp_later(IsoMath.tile_center_screen(tile))
			return
		if b.def.id == _select:
			camera.position = IsoMath.tile_center_screen(b.entrance_tile())
			var panel: BuildingPanel = _game.get("_building_panel")
			panel.show_building(sim.province, b.id)
			return


## Puts the cursor on [param world_pos] once the camera has moved there.
func _warp_later(world_pos: Vector2) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().warp_mouse(get_viewport().get_canvas_transform() * world_pos)


## Finds free ground for the quarter and builds it: finished houses at their level with
## residents, and the roads in front of them.
func _add_quarter(sim: Simulation) -> void:
	var size := sim.province.grid.size
	for y: int in range(2, size.y - 20):
		for x: int in range(2, size.x - 30):
			var at := Vector2i(x, y)
			if _quarter_fits(sim, at):
				_build_quarter(sim, at)
				return
	push_warning("town_shot: no room for the quarter")


func _quarter_fits(sim: Simulation, at: Vector2i) -> bool:
	for y: int in range(-2, 18):
		for x: int in range(-2, 27):
			var t := at + Vector2i(x, y)
			if sim.province.grid.has_road(t):
				continue
			if sim.province.grid.occupant(t) != 0 or sim.province.road_error(t) != &"":
				return false
	return true


func _build_quarter(sim: Simulation, at: Vector2i) -> void:
	for road: Array in QUARTER_ROADS:
		var tiles: Array[Vector2i] = []
		var a: Vector2i = at + road[0]
		var b: Vector2i = at + road[1]
		for y: int in range(a.y, b.y + 1):
			for x: int in range(a.x, b.x + 1):
				tiles.append(Vector2i(x, y))
		sim.execute(BuildRoadCommand.new(tiles))
	for h: Array in QUARTER:
		var error := sim.execute(PlaceBuildingCommand.new(&"hut", at + h[0], true, int(h[1])))
		if error != &"":
			push_warning("town_shot: house at %s: %s" % [at + h[0], error])
			continue
		var b := sim.province.buildings.get_building(sim.ids.next_id - 1)
		b.house.level = int(h[2])
		b.house.residents = b.capacity()
	var c := Vector2(at)
	_blocks = {"all": c + Vector2(13, 8), "row": c + Vector2(4, 1), "corner": c + Vector2(13, 3),
			"back": c + Vector2(23, 3), "patrician_back": c + Vector2(3, 11), "burgher_corner": c + Vector2(13, 12)}
