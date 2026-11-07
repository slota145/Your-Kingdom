extends Node
## TERRAIN SCREENSHOTS (prototype): starts the real game scene, optionally lays a road and a
## small square, moves the camera and saves a screenshot. For checking ground art in the cloud.
##
## Run: godot --path . res://src/prototype/terrain/game_shot.tscn -- --shot=<png>
##      [--tile=X,Y] [--zoom=N] [--roads [--paved]] [--plain]
## --plan_paving (with --roads) orders cobbles on the unpaved part (the marker of planned
## paving); --build=<id> takes that building tool with the cursor on the tile (reach preview).
## --carts puts 4 porters with handcarts and 4 carters with wagons (half loaded) around the
## tile, 8 directions.
## --map=<id> starts a new game on that map (default riverlands).
## --harbour (M5, map coast) puts a shipyard with a boat on its slipway, a fishing wharf, a tar
## kiln and boats in 8 directions (rowing, casting, waiting, hauling the net) near the tile.
## --port (M5 part 2, map coast) puts a port near the tile with the sea merchant's cog moored
## at the quay, goods on the quay yard and in the hold, dockers on the quay and the gangway,
## and foreign cogs sailing in 8 directions; --select=ship opens the cog's panel.
## --quays (N1, with --port) joins a stone quay to the port, lays a timber pier with a mooring
## and a cog tied up at it, a diagonal stone quay, and orders a second pier (outline only).
## --crane (N1 part 2, with --port --quays) puts a cargo crane by the mooring, its operator in
## the middle of a lift (--lift=<0..1>, default 0.35), and a port warehouse with goods.
## --select=<building id> opens the panel of that building.
## --advance=<seconds> runs the simulation that long first (M5 part 3: the landing on Coast).
## --cog_stage=<0..3> (M5 part 3, map coast) puts a shipyard with the player's cog on its
## slipway in that stage (3 = halfway down the slipway at the launch) and the player's cog
## at anchor by a port with a voyage plan; --select=port shows the plan (--scroll=<px> scrolls
## the panel down to it).
## --yards=<id,id,...> (review fix 2026-11-07) puts those workshops in a row from --tile, every
## other one mirrored, each with a full production yard (the stack on its yard tile).
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
## Review fixes 2026-11-07: cobbles ordered on the unpaved part of --roads; a building tool
## (its reach preview) with the cursor on --tile.
var _plan_paving: bool = false
var _build_tool: StringName = &""
var _carts: bool = false
var _harbour: bool = false
var _port: bool = false
var _quays: bool = false
var _crane: bool = false
var _lift: float = 0.35
## Building id whose panel is opened (--select=<id>).
var _select: StringName = &""
var _advance: int = 0
## Scrolls the building panel down this far (px) before the shot (--scroll=N).
var _scroll: int = 0
var _cog_stage: int = -1
## --launch=<0..1> (with --cog_stage=3): how far the launch slide has come; 1 = launched.
var _launch: float = -1.0
var _yards: PackedStringArray = PackedStringArray()


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
		elif arg == "--plan_paving":
			_plan_paving = true
		elif arg.begins_with("--build="):
			_build_tool = StringName(arg.trim_prefix("--build="))
		elif arg == "--carts":
			_carts = true
		elif arg == "--harbour":
			_harbour = true
		elif arg == "--port":
			_port = true
		elif arg == "--quays":
			_quays = true
		elif arg == "--crane":
			_crane = true
		elif arg.begins_with("--lift="):
			_lift = float(arg.trim_prefix("--lift="))
		elif arg.begins_with("--scroll="):
			_scroll = int(arg.trim_prefix("--scroll="))
		elif arg.begins_with("--advance="):
			_advance = int(arg.trim_prefix("--advance="))
		elif arg.begins_with("--cog_stage="):
			_cog_stage = int(arg.trim_prefix("--cog_stage="))
		elif arg.begins_with("--launch="):
			_launch = float(arg.trim_prefix("--launch="))
		elif arg.begins_with("--yards="):
			_yards = arg.trim_prefix("--yards=").split(",")
		elif arg.begins_with("--select="):
			_select = StringName(arg.trim_prefix("--select="))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			Game.start_request = {"map": arg.trim_prefix("--map=")}
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as Node2D
	add_child(_game)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == SETTLE_FRAMES:
		_arrange()
	elif _frames == SHOT_FRAMES - 5 and _scroll > 0:
		var panel := _game.get("_building_panel") as BuildingPanel
		(panel.get("_scroll") as ScrollContainer).scroll_vertical = _scroll
	elif _frames == SHOT_FRAMES and not _shot_path.is_empty():
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _arrange() -> void:
	var sim: Simulation = _game.get("sim")
	var camera: GameCamera = _game.get("camera")
	var view: ProvinceView = _game.get("view")
	view.terrain.organic = not _plain
	if _advance > 0:
		sim.run_ticks(SimClock.seconds_to_ticks(_advance))
		sim.events.drain()
	if _harbour or _port or _cog_stage >= 0:
		sim.province.first_building = &""   # M5 part 3: no start from the ship in these shots
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
		if _plan_paving:
			var plan: Array[Vector2i] = []
			for tile: Vector2i in tiles:
				if tile.x - centre.x < -2:
					plan.append(tile)
			_game.call("_execute", BuildPavingCommand.new(plan))
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
	if _port:
		_place_port(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
		if _quays:
			for b: BuildingState in sim.province.buildings.all():
				if b.def.id == &"port":
					_place_quays(sim, b)
					break
	if _cog_stage >= 0:
		_place_cogs(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if not _yards.is_empty():
		_place_yards(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if _build_tool != &"":
		_game.call("_set_tool", {"kind": &"building", "def": _build_tool})
		get_viewport().warp_mouse(get_viewport().get_visible_rect().size / 2.0)
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == _select:
			(_game.get("_building_panel") as BuildingPanel).show_building(sim.province, b.id)


## Workshops in a row with full yards (--yards).
func _place_yards(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	var x := at.x - 6
	for k: int in _yards.size():
		var def := sim.data.get_building(StringName(_yards[k]))
		var o := k % 2
		var placed := false
		for dy: int in range(0, 12):
			var origin := Vector2i(x, at.y - 2 + (dy if dy % 2 == 0 else -dy))
			if sim.province.placement_error(def, origin, o) == &"" 					and sim.execute(PlaceBuildingCommand.new(def.id, origin, true, o)) == &"":
				placed = true
				break
		x += def.footprint.x + 1
		if not placed:
			continue
		var b := sim.province.buildings.get_building(sim.ids.next_id - 1)
		b.ensure_yard(sim.data)
		if b.yard != null:
			for good: StringName in BuildingState.yard_goods(def, sim.data):
				b.yard.add(good, 999)
	var view: ProvinceView = _game.get("view")
	view.piles.update_yards(sim.province.buildings)


## Places [param id] at the free spot nearest to [param near] (either turn); returns it or null.
func _place_near(sim: Simulation, id: StringName, near: Vector2i) -> BuildingState:
	var def := sim.data.get_building(id)
	for r: int in 20:
		for y: int in range(near.y - r, near.y + r + 1):
			for x: int in range(near.x - r, near.x + r + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) != r:
					continue
				for o: int in 2:
					if sim.province.placement_error(def, Vector2i(x, y), o) != &"":
						continue
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


## N1: quays around [param port]: a stone quay along the shore beside it (two tiles deep),
## a timber pier further on with a mooring and a cog at its end, and an ordered pier.
func _place_quays(sim: Simulation, port: BuildingState) -> void:
	var province := sim.province
	var def := port.def
	var o := port.orientation
	var sea := def.turned(Vector2i(0, 1), o) - def.turned(Vector2i.ZERO, o)
	var along := def.turned(Vector2i(1, 0), o) - def.turned(Vector2i.ZERO, o)
	# First sea tile of the shore column k tiles along from the port.
	var shore := func(k: int) -> Vector2i:
		var t := port.origin + along * k
		for i: int in 24:
			if province.sail_depth(t) > 0:
				return t
			t += sea
		return Agent.NO_TILE
	var lay := func(tiles: Array, quay: int) -> void:
		for t: Vector2i in tiles:
			if province.quay_error(t) == &"":
				province.grid.set_quay(t, quay)
				province.refresh_tile(t)
	var stone: Array = []
	for k: int in range(4, 7):
		var s0: Vector2i = shore.call(k)
		if s0 != Agent.NO_TILE:
			stone.append_array([s0, s0 + sea])
	lay.call(stone, TileGrid.STONE_QUAY)
	var s1: Vector2i = shore.call(7)
	var pier: Array = []
	for j: int in range(-2, 4):   # two tiles of it on the shore
		for m: int in 2:
			pier.append(s1 + sea * j + along * m)
	lay.call(pier, TileGrid.PIER)
	province.refresh_fairways()
	var mooring_at := s1 + sea * 2
	var error := sim.execute(PlaceBuildingCommand.new(&"mooring", mooring_at, true, o))
	print("mooring ", mooring_at, " ", error)
	var mooring := province.buildings.get_building(sim.ids.next_id - 1)
	if error == &"" and mooring != null:
		var cog := ShipUnit.new(province.ids.take(), sim.data.get_ship(SeaMerchant.SHIP),
				IsoMath.tile_center(mooring.berth_tile()), sim.data)
		province.ships[cog.id] = cog
		Harbour.moor(cog, mooring)
		mooring.stock.add(&"wood", 8)
		mooring.stock.add(&"fish", 5)
		if _crane:
			_place_crane(sim, mooring, s1, sea, along, lay)
			# The port warehouse on a stone quay on the other side of the port.
			var store: Array = []
			for k: int in range(-4, -1):
				var s0: Vector2i = shore.call(k)
				if s0 != Agent.NO_TILE:
					store.append_array([s0, s0 + sea, s0 + sea * 2])
			lay.call(store, TileGrid.STONE_QUAY)
			province.refresh_fairways()
			_place_warehouse(sim, store, o)
	# A diagonal stone quay (8 directions, like walls), out to sea and back along the shore.
	var s3: Vector2i = shore.call(16)
	var diagonal := BuildQuayCommand.line(s3 - sea * 2, s3 + (sea - along) * 4)
	var plan := province.quay_plan(diagonal)
	lay.call(plan["tiles"], TileGrid.STONE_QUAY)
	province.refresh_fairways()
	print("diagonal ", (plan["tiles"] as Array).size(), " of ", diagonal.size(), " ", plan["errors"])
	# A slanting timber pier starting on the shore.
	var s4: Vector2i = shore.call(22)
	var slant := BuildQuayCommand.line(s4 - sea * 2, s4 - sea * 2 + (sea - along) * 5)
	lay.call(province.quay_plan(slant)["tiles"], TileGrid.PIER)
	province.refresh_fairways()
	var s2: Vector2i = shore.call(11)
	var ordered: Array[Vector2i] = []
	for j: int in 4:
		ordered.append(s2 + sea * j)
	print("ordered pier ", sim.execute(BuildQuayCommand.new(ordered, TileGrid.PIER)))
	var view: ProvinceView = _game.get("view")
	view.quays.refresh()
	view.buildings.refresh_all()


## N1 part 2: a crane on a pier beside [param mooring] with its operator lifting wood, and a
## port warehouse on a pier block on the shore beside it.
func _place_crane(sim: Simulation, mooring: BuildingState, s1: Vector2i, sea: Vector2i,
		along: Vector2i, lay: Callable) -> void:
	var province := sim.province
	var o := mooring.orientation
	var block: Array = []
	for j: int in range(2, 4):
		for m: int in range(2, 4):
			block.append(s1 + sea * j + along * m)
	var walk: Array = [s1 + sea + along * 2, s1 + sea + along * 3]
	lay.call(block, TileGrid.PIER)
	lay.call(walk, TileGrid.PIER)
	province.refresh_fairways()
	var at: Vector2i = block[0]
	for t: Vector2i in block:
		at = Vector2i(mini(at.x, t.x), mini(at.y, t.y))
	var error := sim.execute(PlaceBuildingCommand.new(&"crane", at, true, o))
	print("crane ", at, " ", error)
	if error != &"":
		return
	var crane := province.buildings.get_building(sim.ids.next_id - 1)
	var operator := province.spawn_agent(Cranes.OPERATOR_KIND, crane.entrance_tile())
	province.assign_worker(operator, crane)
	var task := Task.new()
	task.kind = Task.KIND_RECIPE
	task.recipe_id = crane.def.recipe.id
	task.steps = crane.def.recipe.steps
	task.step_index = 1
	task.bb = {"_lift": roundi(_lift * Cranes.CYCLE_TICKS), "_out": 1, "good": "wood", "_load": 3,
			"_port": mooring.id}
	operator.task = task
	operator.activity = &"walk"
	operator.facing = IsoMath.screen_dir(IsoMath.tile_center(mooring.berth_tile()) - operator.pos)


func _place_warehouse(sim: Simulation, store: Array, o: int) -> void:
	var province := sim.province
	var corner: Vector2i = store[0]
	for t: Vector2i in store:
		corner = Vector2i(mini(corner.x, t.x), mini(corner.y, t.y))
	var error := sim.execute(PlaceBuildingCommand.new(&"port_warehouse", corner, true, o))
	print("port warehouse ", corner, " ", error)
	if error == &"":
		var warehouse := province.buildings.get_building(sim.ids.next_id - 1)
		warehouse.stock.add(&"planks", 12)
		warehouse.stock.add(&"tar", 6)
		warehouse.stock.add(&"cloth", 5)
		warehouse.stock.add(&"wood", 10)


func _place_port(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	var province := sim.province
	var port := _place_near(sim, &"port", at)
	print("port ", port.origin if port else null)
	if port == null:
		return
	var def := sim.data.get_ship(SeaMerchant.SHIP)
	var cog := ShipUnit.new(province.ids.take(), def, IsoMath.tile_center(port.berth_tile()), sim.data)
	province.ships[cog.id] = cog
	cog.hold.add(&"planks", 14)
	cog.hold.add(&"tar", 6)
	cog.hold.add(&"cloth", 10)
	cog.hold.add(&"wood", 7)
	Harbour.moor(cog, port)
	var trader := province.sea_merchant
	trader.state = SeaMerchant.State.TRADING
	trader.ship_id = cog.id
	trader.port_id = port.id
	trader.leave_at = province.tick + SimClock.seconds_to_ticks(150)
	trader.paid = cog.hold.totals()
	trader.bought = 7
	trader.earned = 14
	trader.spent = 36
	port.stock.add(&"wood", 9)
	port.stock.add(&"fish", 6)
	port.stock.add(&"planks", 6)
	port.stock.add(&"tar", 3)
	# Dockers: one walking over the quay with wood, one handing tar over at the ship.
	var points := Harbour.gangway_points(port)
	for k: int in 2:
		var docker := province.spawn_agent(Harbour.DOCKER_KIND, port.entrance_tile())
		province.assign_worker(docker, port)
		docker.pos = points[0].lerp(points[1], 0.55) if k == 0 else points[2]
		docker.prev_pos = docker.pos
		docker.carry_good = &"wood" if k == 0 else &"tar"
		docker.carry_amount = 1
		docker.activity = &"walk" if k == 0 else Harbour.HAND_OVER
		docker.facing = IsoMath.Dir.SW if k == 0 else IsoMath.Dir.NE
		if k == 1:
			# On the ship's deck, as in the game (the view draws him over the ship).
			var task := Task.new()
			task.kind = Task.KIND_TRANSPORT
			task.bb = {"_gw": 1}
			docker.task = task
	var porter := province.spawn_agent(&"porter", port.door_front_tile())
	porter.carry_good = &"fish"
	porter.carry_amount = 1
	porter.activity = &"walk"
	porter.facing = IsoMath.Dir.NW
	# Foreign cogs in 8 directions out at sea (not with --quays: they would hide the quays).
	var placed := IsoMath.DIR_COUNT if _quays else 0
	for y: int in range(at.y + 4, at.y + 40, 3):
		for x: int in range(at.x - 20, at.x + 30, 7):
			var tile := Vector2i(x, y)
			if placed >= IsoMath.DIR_COUNT or not province.grid.is_inside(tile) \
					or not province.cog_nav.is_walkable(tile) or tile.distance_to(port.berth_tile()) < 6:
				continue
			var sailing := ShipUnit.new(province.ids.take(), def, IsoMath.tile_center(tile), sim.data)
			sailing.facing = placed
			province.ships[sailing.id] = sailing
			placed += 1
	if _select == &"ship":
		(_game.get("_ship_panel") as ShipPanel).show_ship(province, cog.id)


## The player's cog on a shipyard's slipway in stage _cog_stage and another one at anchor by
## a port, with a voyage plan (M5 part 3).
func _place_cogs(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	var province := sim.province
	var shipyard := _place_near(sim, &"shipyard", at)
	var port := _place_near(sim, &"port", at + Vector2i(-6, 4))
	print("shipyard ", shipyard.origin if shipyard else null, " port ", port.origin if port else null)
	if shipyard != null:
		sim.execute(OrderShipCommand.new(shipyard.id, &"cog"))
		var build := Ships.open_build(province, shipyard)
		build.stage = _cog_stage
		build.stage_started = true
		build.work_left = build.stage_ticks / 2 if _cog_stage == 3 else build.stage_ticks
		if _cog_stage == 3 and _launch >= 0.0:
			var slide_ticks := mini(SimClock.seconds_to_ticks(ShipLayer.LAUNCH_SLIDE), build.stage_ticks)
			build.work_left = maxi(roundi(slide_ticks * (1.0 - _launch)), 0)
			if _launch >= 1.0:
				Ships.close_build(province, build, true)
		var wright := province.spawn_agent(&"shipwright", shipyard.entrance_tile())
		wright.activity = &"hammer"
		wright.facing = IsoMath.Dir.SW
	if port != null:
		var cog := Ships.launch(province, sim.data.get_ship(&"cog"), port)
		cog.home_id = port.id
		cog.dock_id = 0
		cog.voyage.anchor = Voyage.anchorage(province, cog, port.berth_tile())
		cog.pos = IsoMath.tile_center(cog.voyage.anchor)
		cog.prev_pos = cog.pos
		cog.facing = IsoMath.Dir.SW
		cog.voyage.sell = {&"wood": 20, &"fish": 10}
		cog.voyage.order = {&"cloth": 5}
		cog.voyage.last_sold = 30
		cog.voyage.last_earned = 105
		cog.voyage.last_bought = 10
		cog.voyage.last_spent = 90
