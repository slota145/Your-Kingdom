extends Node
## TERRAIN SCREENSHOTS (prototype): starts the real game scene, optionally lays a road and a
## small square, moves the camera and saves a screenshot. For checking ground art in the cloud.
##
## Run: godot --path . res://src/prototype/terrain/game_shot.tscn -- --shot=<png>
##      [--tile=X,Y] [--zoom=N] [--roads [--paved]] [--plain]
## --carts puts 4 porters with handcarts and 4 carters with wagons (half loaded) around the
## tile, 8 directions.
## --map=<id> starts a new game on that map (default riverlands).
## --harbour (M5, map coast) puts a shipyard with a boat on its slipway, a fishing wharf, a tar
## kiln and boats in 8 directions (rowing, casting, waiting, hauling the net) near the tile.
## --paved cobbles the square and the east part of the long road at once (M4b-3 art check).

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
var _paved: bool = false
var _carts: bool = false
var _harbour: bool = false


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
		elif arg == "--paved":
			_paved = true
		elif arg == "--carts":
			_carts = true
		elif arg == "--harbour":
			_harbour = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			Game.start_request = {"map": arg.trim_prefix("--map=")}
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
			if _paved and tile.x - centre.x >= -2:
				sim.province.grid.set_paved(tile, true)
				sim.province.refresh_tile(tile)
			view.terrain.refresh_tile(tile)
	if _carts:
		var at := _tile if _tile.x >= 0 else sim.province.grid.size / 2
		Game.paused = true
		for dir: int in IsoMath.DIR_COUNT:
			var porter := sim.province.spawn_agent(&"porter", at + Vector2i(dir % 4 * 3 - 4, dir / 4 * 4 - 2))
			porter.vehicle = Carriers.HANDCART
			if dir >= 4:
				porter.kind = Carriers.CARTER_KIND
				porter.vehicle = Carriers.WAGON
			porter.facing = dir
			porter.activity = &"walk"
			if dir % 2 == 0:
				porter.carry_good = &"wood"
				porter.carry_amount = 3

	if _harbour:
		_place_harbour(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)


## Places [param id] at the free spot nearest to [param near] (either turn); returns it or null.
func _place_near(sim: Simulation, id: StringName, near: Vector2i) -> BuildingState:
	var def := sim.data.get_building(id)
	for r: int in 20:
		for y: int in range(near.y - r, near.y + r + 1):
			for x: int in range(near.x - r, near.x + r + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) != r:
					continue
				for o: int in 2:
					if sim.execute(PlaceBuildingCommand.new(id, Vector2i(x, y), true, o)) == &"":
						return sim.province.buildings.get_building(sim.ids.next_id - 1)
	return null


func _place_harbour(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	var province := sim.province
	var shipyard := _place_near(sim, &"shipyard", at)
	var wharf := _place_near(sim, &"fishing_wharf", at + Vector2i(-2, 6))
	_place_near(sim, &"tar_kiln", at + Vector2i(-8, -4))
	print("shipyard ", shipyard.origin if shipyard else null, " wharf ", wharf.origin if wharf else null)
	if shipyard != null:
		sim.execute(OrderShipCommand.new(shipyard.id, &"fishing_boat"))
		var build := Ships.open_build(province, shipyard)
		build.stage = 1
		build.stage_started = true
		var wright := province.spawn_agent(&"shipwright", shipyard.entrance_tile())
		wright.activity = &"hammer"
		wright.facing = IsoMath.Dir.SW
	if wharf != null:
		var moored := Ships.launch(province, sim.data.get_ship(&"fishing_boat"), wharf)
		moored.home_id = wharf.id
	var activities: Array[StringName] = [&"sail", &"cast_net", &"wait_net", &"haul_net"]
	var placed := 0
	for y: int in range(at.y - 2, at.y + 26):
		for x: int in range(at.x - 4, at.x + 26):
			var tile := Vector2i(x, y)
			if placed >= IsoMath.DIR_COUNT or not province.boat_nav.is_walkable(tile) or (x + y) % 5 != 0 \
					or province.boat_nav.is_walkable(tile + Vector2i(-3, 0)) == false:
				continue
			var boat := Ships.launch(province, sim.data.get_ship(&"fishing_boat"), wharf if wharf != null else shipyard)
			boat.pos = IsoMath.tile_center(tile)
			boat.prev_pos = boat.pos
			boat.dock_id = 0
			boat.facing = placed
			var fisher := province.spawn_agent(&"fisher", tile)
			Ships.board(boat, fisher)
			var activity := activities[placed % activities.size()]
			fisher.activity = &"idle" if activity == &"sail" else activity
			boat.activity = activity
			if activity == &"sail":
				boat.path_state = ShipUnit.PathState.MOVING
			placed += 1
