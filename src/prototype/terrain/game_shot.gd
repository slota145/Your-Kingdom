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
## --g1=finished (G1) puts the pioneer set drawn by PixelLab around --tile: the pioneer camp
## as drawn and mirrored, huts in their 3 looks and turned 4 ways (2 and 3 show the back), the
## woodcutter, quarry and fishing hut both ways with full yards; --g1=sites puts their
## building sites in both stages.
## --g2 (G2) puts stockpiles around --tile with every good drawn by PixelLab, each slot
## holding a different number of pieces (1 up to a full stack), so the stacks grow in sight.
## --m7=walls|battle|raid [--raid_seconds=<s>] (M7 part 2): walls, a fight, a bandit raid.
## --map=lakeland --m7=storm [--raid_seconds=<s>] (M8 part 4): an AI ruler's army storms the town.
## --m7=finished|sites|army (M7 part 1): the new buildings drawn by PixelLab around --tile
## (finished both ways with full yards and a herd of horses, or their sites in both stages),
## or a barracks with an armoury and 16 soldiers (4 of each kind) in the ranks; --drill shows
## the ranks while they drill.
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
## --vineyard (review fix 2026-11-07): a vineyard at --tile with rows of fields in every stage.
var _vineyard: bool = false
var _yards: PackedStringArray = PackedStringArray()
## --g1=finished|sites (G1): which half of the pioneer set to lay out; "" = none.
var _g1: String = ""
var _g2: bool = false
## --m7=finished|sites|army (M7 part 1); "" = none.
var _m7: String = ""
## --raid_seconds=<s>: how long the raid runs before the shot (--m7=raid).
var _raid_seconds: float = 25.0
## --focus=x,y: the camera looks at this tile after everything is placed (the layout stays at
## --tile).
var _focus: Vector2i = Vector2i(-1, -1)
var _drill: bool = false
## --siege=<province def id> (--m7=siege).
var _siege: StringName = &"iron_wold"
## --bridges (B1): timber, stone and diagonal bridges over the river near --tile, one ordered,
## people and a wagon on them.
var _bridges: bool = false
## --j1ships [--j1stage=<0..2>] (J1 part 3): the large shipyard with a galleon on the slipway
## and the six new ships at anchor near --tile.
var _j1ships: bool = false
var _j1stage: int = 2
## --p2 [--p2_seconds=<s>] (P2 part 1): a stone quay along the shore near --tile with bollards
## and ships moored at them, port warehouses of three sizes, a dockers' hut and a dockers'
## house standing 2 rows on piles, the dockers unloading for <s> seconds (default 25).
var _p2: bool = false
var _p2_seconds: int = 25
## --p2troops=<s> (P2 part 2, with --p2): eight soldiers ordered aboard a warship at anchor,
## run for <s> seconds; --select=warship|caravel opens that ship's panel.
var _p2troops: int = -1
## --hard_shore (B1 part 2): the shoreline as before the soft shore, to compare.
var _hard_shore: bool = false
## --stilts=<id,id,...> (B1 part 2): those buildings placed near --tile with a row over the water
## on piles.
var _stilts: PackedStringArray = PackedStringArray()


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
		elif arg == "--vineyard":
			_vineyard = true
		elif arg.begins_with("--yards="):
			_yards = arg.trim_prefix("--yards=").split(",")
		elif arg == "--g2":
			_g2 = true
		elif arg.begins_with("--m7="):
			_m7 = arg.trim_prefix("--m7=")
		elif arg.begins_with("--focus="):
			var xy := arg.trim_prefix("--focus=").split(",")
			_focus = Vector2i(int(xy[0]), int(xy[1]))
		elif arg.begins_with("--raid_seconds="):
			_raid_seconds = float(arg.trim_prefix("--raid_seconds="))
		elif arg.begins_with("--stilts="):
			_stilts = arg.trim_prefix("--stilts=").split(",")
		elif arg == "--hard_shore":
			_hard_shore = true
		elif arg == "--j1ships":
			_j1ships = true
		elif arg == "--p2":
			_p2 = true
		elif arg.begins_with("--p2troops="):
			_p2troops = int(arg.trim_prefix("--p2troops="))
		elif arg.begins_with("--p2_seconds="):
			_p2_seconds = int(arg.trim_prefix("--p2_seconds="))
		elif arg.begins_with("--j1stage="):
			_j1stage = int(arg.trim_prefix("--j1stage="))
		elif arg == "--bridges":
			_bridges = true
		elif arg == "--drill":
			_drill = true
		elif arg.begins_with("--siege="):
			_siege = StringName(arg.trim_prefix("--siege="))
		elif arg.begins_with("--g1"):
			_g1 = arg.trim_prefix("--g1=") if arg.begins_with("--g1=") else "finished"
		elif arg.begins_with("--select="):
			_select = StringName(arg.trim_prefix("--select="))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			Game.start_request = {"map": arg.trim_prefix("--map=")}
		elif arg == "--world":
			Game.start_request = {"world": "kingdom"}
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
	if _hard_shore:
		(view.terrain.get("_material") as ShaderMaterial).set_shader_parameter("soft_shore", false)
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
	if _vineyard:
		_place_vineyard(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if _g2:
		_place_g2(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if _g1 != "":
		_place_g1(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if _m7 != "":
		_place_m7(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if not _stilts.is_empty():
		_place_stilts(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if _j1ships:
		_place_j1ships(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if _p2:
		_place_p2(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if _bridges:
		_place_bridges(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if not _yards.is_empty():
		_place_yards(sim, _tile if _tile.x >= 0 else sim.province.grid.size / 2)
	if _focus.x >= 0:
		camera.position = IsoMath.tile_center_screen(_focus)
	if _build_tool != &"":
		_game.call("_set_tool", {"kind": &"building", "def": _build_tool})
		get_viewport().warp_mouse(get_viewport().get_visible_rect().size / 2.0)
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == _select:
			(_game.get("_building_panel") as BuildingPanel).show_building(sim.province, b.id)


## J1 part 3: the large shipyard nearest [param at] with a galleon on the slipway, and the six
## new ships at anchor around.
func _place_j1ships(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	var province := sim.province
	province.first_building = &""
	sim.treasury.gold = 5000
	var yard := _place_near(sim, &"large_shipyard", at)
	print("large shipyard ", yard.origin if yard != null else null)
	if yard != null:
		sim.execute(OrderShipCommand.new(yard.id, &"galleon"))
		var build := Ships.open_build(province, yard)
		build.stage = _j1stage
		build.stage_started = true
		build.work_left = build.stage_ticks
	var spot := yard.berth_tile() if yard != null else at
	var k := 0
	for id: StringName in [&"caravel", &"carrack", &"galleon", &"caravel_war", &"carrack_war", &"galleon_war"]:
		var def := sim.data.get_ship(id)
		var ship := ShipUnit.new(sim.ids.take(), def, IsoMath.tile_center(spot), sim.data)
		var near := spot + Vector2i(-14 + 7 * (k % 3), 6 + 7 * (k / 3))
		var anchor := Voyage.anchorage(province, ship, near)
		if anchor == Agent.NO_TILE:
			continue
		ship.pos = IsoMath.tile_center(anchor)
		ship.prev_pos = ship.pos
		ship.facing = [1, 2, 3, 5, 6, 7][k]
		if ship.voyage != null:
			ship.voyage.anchor = anchor
		province.ships[ship.id] = ship
		k += 1


## P2 part 1: the shore south of [param at] (the sea lies to +y): a stone quay two rows deep
## along it, bollards with ships, port warehouses, a dockers' hut and a dockers' house.
func _place_p2(sim: Simulation, at: Vector2i) -> void:
	var province := sim.province
	province.first_building = &""
	sim.treasury.gold = 5000
	# The first sea tile of each column, found before the quay covers it (a quay is no sea).
	var shores: Dictionary[int, Vector2i] = {}
	for x: int in range(at.x - 8, at.x + 18):
		shores[x] = Agent.NO_TILE
		for y: int in range(at.y, at.y + 30):
			if province.sail_depth(Vector2i(x, y)) > 0:
				shores[x] = Vector2i(x, y)
				break
	var shore := func(x: int) -> Vector2i:
		return shores.get(x, Agent.NO_TILE)
	var quay: Array[Vector2i] = []
	for x: int in range(at.x - 6, at.x + 9):
		var s0: Vector2i = shore.call(x)
		if s0 != Agent.NO_TILE:
			for j: int in 2:
				var t := s0 + Vector2i(0, j)
				var why := province.quay_error(t)
				if why == &"":
					province.grid.set_quay(t, TileGrid.STONE_QUAY)
					province.refresh_tile(t)
					quay.append(t)
				else:
					print("quay ", t, ": ", why)
	province.refresh_fairways()
	print("stone quay ", quay.size())
	var place := func(id: StringName, origin: Vector2i, o: int) -> BuildingState:
		var error := sim.execute(PlaceBuildingCommand.new(id, origin, true, o))
		print(id, " at ", origin, " turned ", o, ": ", error)
		return province.buildings.get_building(sim.ids.next_id - 1) if error == &"" else null
	var s_mid: Vector2i = shore.call(at.x)
	var warehouse: BuildingState = place.call(&"port_warehouse_small", s_mid + Vector2i(-2, -3), 0)
	if warehouse == null:
		warehouse = _place_near(sim, &"port_warehouse_small", s_mid + Vector2i(-2, -4))
	place.call(&"port_store", s_mid + Vector2i(1, -2), 0)
	var hut: BuildingState = _place_near(sim, &"docker_hut", s_mid + Vector2i(4, -4))
	# The dockers' house on the far end, two rows on piles over the sea.
	var house: BuildingState = null
	for x: int in range(at.x + 9, at.x + 16):
		var s0: Vector2i = shore.call(x)
		if s0 == Agent.NO_TILE:
			continue
		for o: int in 4:
			if province.placement_error(sim.data.get_building(&"docker_house"), s0 + Vector2i(0, -1), o) == &"":
				house = place.call(&"docker_house", s0 + Vector2i(0, -1), o)
				break
		if house != null:
			break
	# Stone quay on the water left of the house, so it joins the quay strip with no gap.
	if house != null:
		for y: int in range(house.origin.y, house.origin.y + house.def.footprint.y + 1):
			for x: int in range(house.origin.x - 2, house.origin.x):
				var t := Vector2i(x, y)
				if province.sail_depth(t) > 0 and province.quay_error(t) == &"":
					province.grid.set_quay(t, TileGrid.STONE_QUAY)
					province.refresh_tile(t)
		province.refresh_fairways()
	var ships: Array[ShipUnit] = []
	for k: int in 2:
		var x := at.x - 5 + 10 * k
		var s0: Vector2i = shore.call(x)
		var bollard: BuildingState = place.call(&"bollard", s0 + Vector2i(0, 1), 0) if s0 != Agent.NO_TILE else null
		if bollard == null:
			continue
		var def := sim.data.get_ship(&"caravel" if k == 0 else SeaMerchant.SHIP)
		var ship := ShipUnit.new(province.ids.take(), def, IsoMath.tile_center(bollard.berth_tile()), sim.data)
		province.ships[ship.id] = ship
		Harbour.moor(ship, bollard)
		ship.hold.add(&"wood", 6)
		ship.hold.add(&"fish", 4)
		ships.append(ship)
		if warehouse != null:
			province.jobs.add(&"wood", 6, ship.id, Harbour.yard_id(province, bollard))
			province.jobs.add(&"fish", 4, ship.id, Harbour.yard_id(province, bollard))
	for workplace: BuildingState in [hut, house]:
		if workplace == null:
			continue
		for i: int in workplace.def.worker_count():
			var docker := province.spawn_agent(Harbour.DOCKER_KIND, workplace.door_front_tile())
			province.assign_worker(docker, workplace)
	var warship: ShipUnit = null
	if _p2troops >= 0:
		var s_free: Vector2i = shore.call(at.x + 1)
		place.call(&"bollard", s_free + Vector2i(0, 1), 0)
		warship = ShipUnit.new(sim.ids.take(), sim.data.get_ship(&"carrack_war"), IsoMath.tile_center(at + Vector2i(2, 16)), sim.data)
		var anchor := Voyage.anchorage(province, warship, at + Vector2i(2, 14))
		if anchor != Agent.NO_TILE:
			warship.pos = IsoMath.tile_center(anchor)
			warship.prev_pos = warship.pos
		province.ships[warship.id] = warship
		var squad: Array[int] = []
		var kinds: Array[StringName] = [&"spearman", &"halberdier", &"crossbowman", &"archer"]
		for i: int in 8:
			var agent := province.spawn_agent(kinds[i % 4], s_mid + Vector2i(-3 + i % 4, -6 + i / 4))
			agent.combat = CombatState.new(sim.data.get_unit(agent.kind).combat.hp)
			squad.append(agent.id)
		print("board ", sim.execute(BoardShipCommand.new(squad, warship.id)))
	sim.run_ticks(SimClock.seconds_to_ticks(_p2troops if _p2troops >= 0 else _p2_seconds))
	sim.events.drain()
	Game.paused = true
	var view: ProvinceView = _game.get("view")
	view.quays.refresh()
	view.buildings.refresh_all()
	var panel := _game.get("_ship_panel") as ShipPanel
	if _select == &"warship" and warship != null:
		panel.show_ship(province, warship.id)
	elif _select == &"caravel" and not ships.is_empty():
		panel.show_ship(province, ships[0].id)


## B1: bridges over the river near [param at]: a timber one, a stone one, a diagonal timber one
## and one only ordered, scanning rows for the first crossing west to east.
func _place_bridges(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	var province := sim.province
	province.first_building = &""
	var crossing := func(y: int) -> Array:
		for x: int in range(at.x - 14, at.x + 14):
			var t := Vector2i(x, y)
			if province.is_bridgeable(t) and not province.is_bridgeable(t - Vector2i(1, 0)):
				var x1 := x
				while province.is_bridgeable(Vector2i(x1 + 1, y)):
					x1 += 1
				return [Vector2i(x - 1, y), Vector2i(x1 + 1, y)]
		return []
	var view_nature := func(tile: Vector2i) -> void:
		(_game.get("view") as ProvinceView).nature.refresh(tile)
	var lay := func(from: Vector2i, to: Vector2i, kind: int) -> Array[Vector2i]:
		var plan := province.bridge_plan(from, to)
		var tiles: Array[Vector2i] = []
		tiles.assign(plan["tiles"])
		print("bridge ", from, "->", to, " ", plan["error"], " ", tiles.size())
		for tile: Vector2i in tiles:
			if province.resources.has_node(tile):
				province.resources.clear(tile)
				view_nature.call(tile)
			province.grid.set_bridge(tile, kind)
			province.refresh_tile(tile)
		return tiles
	var timber: Array[Vector2i] = []
	var stone: Array[Vector2i] = []
	var a: Array = crossing.call(at.y - 4)
	if not a.is_empty():
		timber = lay.call(a[0], a[1], TileGrid.TIMBER_BRIDGE)
	var b: Array = crossing.call(at.y + 1)
	if not b.is_empty():
		stone = lay.call(b[0], b[1], TileGrid.STONE_BRIDGE)
	# A diagonal bridge further down, from the west bank down to the south-east.
	var c: Array = crossing.call(at.y + 6)
	if not c.is_empty():
		for k: int in range(3, 12):
			var from: Vector2i = c[0] - Vector2i(1, 1)
			if province.bridge_plan(from, from + Vector2i(k, k))["error"] == &"":
				lay.call(from, from + Vector2i(k, k), TileGrid.TIMBER_BRIDGE)
				break
	# A diagonal stone bridge further up.
	var e: Array = crossing.call(at.y - 10)
	if not e.is_empty():
		for k: int in range(3, 12):
			var from: Vector2i = e[0] - Vector2i(1, 1)
			if province.bridge_plan(from, from + Vector2i(k, k))["error"] == &"":
				lay.call(from, from + Vector2i(k, k), TileGrid.STONE_BRIDGE)
				break
	var d: Array = crossing.call(at.y + 10)
	if not d.is_empty():
		print("ordered bridge ", sim.execute(BuildBridgeCommand.new(d[0], d[1], TileGrid.STONE_BRIDGE)))
	# A road dragged over the river further down (B1, owner's request 2026-11-08): the game
	# orders a timber bridge over the water and the road on both banks.
	var road_from := Vector2i(at.x - 8, at.y + 14)
	var drag: Array[Vector2i] = [road_from]
	var last := road_from
	while last != road_from + Vector2i(16, 2):
		var dd := road_from + Vector2i(16, 2) - last
		if absi(dd.x) >= absi(dd.y):
			last.x += signi(dd.x)
		else:
			last.y += signi(dd.y)
		drag.append(last)
	for road_crossing: Dictionary in province.road_crossings(drag):
		print("road crossing ", road_crossing["from"], "->", road_crossing["to"], " ", (road_crossing["plan"] as Dictionary)["error"])
		if (road_crossing["plan"] as Dictionary)["error"] == &"":
			_game.call("_execute", BuildBridgeCommand.new(road_crossing["from"], road_crossing["to"], TileGrid.TIMBER_BRIDGE))
			drag.append_array(road_crossing["link"])
	var road: Array[Vector2i] = []
	for t: Vector2i in drag:
		if province.road_error(t) == &"":
			road.append(t)
	_game.call("_execute", BuildRoadCommand.new(road))
	for t: Vector2i in road:
		(_game.get("view") as ProvinceView).terrain.refresh_tile(t)
	# People and a wagon on the bridges.
	var walkers: Array[Vector2i] = []
	if timber.size() >= 4:
		walkers.append_array([timber[1], timber[3]])
	if stone.size() >= 3:
		walkers.append(stone[2])
	for i: int in walkers.size():
		var porter := sim.province.spawn_agent(&"porter", walkers[i])
		porter.facing = 1 if i % 2 == 0 else 5
		porter.activity = &"walk"
		porter.carry_good = &"wood"
		porter.carry_amount = 1
	if stone.size() >= 3:
		var carter := sim.province.spawn_agent(&"porter", stone[stone.size() - 2])
		carter.kind = Carriers.CARTER_KIND
		carter.vehicle = Carriers.WAGON
		carter.facing = 5
		carter.activity = &"walk"
	var view: ProvinceView = _game.get("view")
	view.bridges.refresh()


## A vineyard with 5 rows of 3 fields in front of it: pruned, budding, leafy, green grapes,
## ripe (--vineyard).
func _place_vineyard(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	var province := sim.province
	province.rare_resource = &"vines"   # a wine province, for the shot
	var vineyard := _place_near(sim, &"vineyard", at)
	if vineyard == null:
		return
	var view: ProvinceView = _game.get("view")
	var grow := 1000
	for row: int in 5:
		for k: int in 3:
			var tile := vineyard.origin + Vector2i(k - 1, 4 + row)
			if not province.grid.is_inside(tile) or province.fields.has_field(tile):
				continue
			province.fields.add(tile, vineyard.id)
			match row:
				0:
					province.fields.set_stage(tile, FieldStore.Stage.PLOWED)
				4:
					province.fields.set_stage(tile, FieldStore.Stage.RIPE)
				_:
					# Sown so that the growth stage is row (1..3) now.
					province.fields.sow(tile, province.tick - grow * (row * 2 - 1) / 6, grow)
			view.terrain.refresh_tile(tile)
	view.vines.refresh()
	(_game.get("camera") as GameCamera).position = IsoMath.tile_center_screen(vineyard.origin + Vector2i(0, 5))


## Stockpiles with every good of G2 (--g2): three stockpiles side by side, one good per slot,
## each slot a different number of pieces.
func _place_g2(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	sim.province.first_building = &""
	var goods: Array[StringName] = [&"wood", &"planks", &"stone", &"bricks", &"clay", &"flour",
			&"grain", &"bread", &"fish", &"grapes", &"meat", &"hides", &"wool", &"cloth",
			&"clothes", &"hops", &"beer", &"wine", &"mead", &"honey", &"tar"]
	var def := sim.data.get_building(&"stockpile")
	var k := 0
	for n: int in 3:
		var origin := at + Vector2i(-7 + 5 * n, -2)
		if sim.execute(PlaceBuildingCommand.new(def.id, origin, true, 0)) != &"":
			print("g2: could not place a stockpile at ", origin)
			continue
		var b: BuildingState = null
		for placed: BuildingState in sim.province.buildings.all():
			if placed.origin == origin and placed.def == def:
				b = placed
		for slot: int in 7:
			if k >= goods.size():
				break
			var good := goods[k]
			var size := b.stock.stack_size(good)
			# 1, a third, half, two thirds, full... so each stack shows a different size.
			var amounts: Array[int] = [size, 1, size / 3, size / 2, size * 2 / 3, size - 1, size]
			b.stock.add(good, maxi(1, amounts[k % amounts.size()]))
			k += 1


## The pioneer set of G1 (--g1): rows of finished buildings and sites, see the header.
func _place_g1(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	sim.province.first_building = &""
	# [id, screen column (96 px), screen row (32 px), orientation, look, site phase (0 = finished)]
	var plan: Array = [
		[&"pioneer_camp", -3, -5, 0, 0, 0], [&"pioneer_camp", 1, -5, 1, 0, 0],
		[&"hut", -5, 0, 0, 1, 0], [&"hut", -3, 0, 0, 2, 0], [&"hut", -1, 0, 0, 3, 0],
		[&"hut", 1, 0, 1, 2, 0], [&"hut", 3, 0, 2, 1, 0], [&"hut", 5, 0, 3, 3, 0],
		[&"woodcutter", -5, 5, 0, 0, 0], [&"quarry", -3, 5, 0, 0, 0], [&"fishing_hut", -1, 5, 0, 0, 0],
		[&"woodcutter", 1, 5, 1, 0, 0], [&"quarry", 3, 5, 1, 0, 0], [&"fishing_hut", 5, 5, 1, 0, 0],
	]
	if _g1 == "sites":
		plan = [
			[&"pioneer_camp", -3, -4, 0, 0, 1], [&"pioneer_camp", 1, -4, 0, 0, 2],
			[&"hut", -5, 1, 0, 0, 1], [&"hut", -3, 1, 0, 0, 2], [&"hut", -1, 1, 2, 0, 2],
			[&"woodcutter", 1, 1, 0, 0, 1], [&"woodcutter", 3, 1, 0, 0, 2],
			[&"quarry", -3, 6, 0, 0, 1], [&"quarry", -1, 6, 0, 0, 2],
			[&"fishing_hut", 1, 6, 0, 0, 1], [&"fishing_hut", 3, 6, 0, 0, 2],
		]
	# Prototype only: the camp is unique in the game, the shot shows it 4 times.
	sim.data.get_building(&"pioneer_camp").unique = false
	# Prototype only: the fishing hut may stand away from water in the shot.
	sim.data.get_building(&"fishing_hut").needs_terrain_near = &""
	for item: Array in plan:
		var def := sim.data.get_building(item[0])
		# Screen column c and row r to grid: x - y = 3c (96 px), x + y = 2r (32 px).
		var c: int = item[1]
		var r: int = item[2]
		var origin := at + Vector2i((3 * c + 2 * r) / 2, (2 * r - 3 * c) / 2)
		var phase: int = item[5]
		var b: BuildingState = null
		for dy: int in range(0, 3):
			var o := origin + Vector2i(dy, dy)
			if sim.province.placement_error(def, o, item[3]) == &"" and sim.execute(
					PlaceBuildingCommand.new(def.id, o, phase == 0, item[3], item[4])) == &"":
				for placed: BuildingState in sim.province.buildings.all():
					if placed.origin == o and placed.def == def:
						b = placed
				break
		if b == null:
			print("g1: could not place ", item)
			continue
		if phase > 0:
			var site := sim.province.sites.get(b.site_id) as ConstructionSite
			if site != null:
				site.phase = mini(phase, site.phase_count())
		elif b.def.id != &"hut" and b.def.id != &"pioneer_camp":
			b.ensure_yard(sim.data)
			if b.yard != null:
				for good: StringName in BuildingState.yard_goods(def, sim.data):
					b.yard.add(good, 999)
	var view: ProvinceView = _game.get("view")
	view.piles.update_yards(sim.province.buildings)


## M7 part 1 (--m7): the new buildings, their sites, or the army at its barracks.
func _place_m7(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	sim.province.first_building = &""
	sim.province.rare_resource = &"horses"   # a stud farm in the shot
	sim.data.get_building(&"mine").needs_node_near = &""   # the mine anywhere in the shot
	sim.treasury.gold = 5000   # sites cost gold
	if _m7 == "ballista":
		_place_ballistas(sim, at)
		return
	if _m7 == "army" or _m7 == "army2" or _m7 == "army3":
		_place_army(sim, at)
		return
	if _m7 == "siege":
		_place_siege(sim)
		return
	if _m7 == "fleet":
		_place_fleet(sim, at)
		return
	if _m7 == "walls":
		_place_walls(sim, at)
		return
	if _m7 == "battle":
		_place_walls(sim, at)
		_place_battle(sim, at)
		return
	if _m7 == "raid":
		_place_walls(sim, at)
		_place_raid(sim, at)
		return
	if _m7 == "storm":
		_place_walls(sim, at)
		_place_storm(sim, at)
		return
	var ids: Array[StringName] = [&"charcoal_burner", &"mine", &"smelter", &"blacksmith",
			&"armourer", &"bowyer"]
	var plan: Array = []
	if _m7 == "sites":
		for k: int in ids.size():
			plan.append([ids[k], -5 + 2 * k, -4, 0, 1])
			plan.append([ids[k], -5 + 2 * k, 0, 0, 2])
		var big: Array[StringName] = [&"stud_farm", &"armoury", &"barracks"]
		for k: int in big.size():
			plan.append([big[k], -4 + 4 * k, 5, 0, 1])
			plan.append([big[k], -4 + 4 * k, 10, 0, 2])
	else:
		for k: int in ids.size():
			plan.append([ids[k], -5 + 2 * k, -4, 0, 0])
			plan.append([ids[k], -5 + 2 * k, 0, 1, 0])
		plan.append([&"stud_farm", -4, 5, 0, 0])
		plan.append([&"armoury", -1, 5, 0, 0])
		plan.append([&"barracks", 2, 5, 0, 0])
		plan.append([&"barracks", 5, 5, 1, 0])
	for item: Array in plan:
		var def := sim.data.get_building(item[0])
		var c: int = item[1]
		var r: int = item[2]
		var origin := at + Vector2i((3 * c + 2 * r) / 2, (2 * r - 3 * c) / 2)
		var phase: int = item[4]
		var b: BuildingState = null
		for dy: int in range(0, 3):
			var o := origin + Vector2i(dy, dy)
			if sim.province.placement_error(def, o, item[3]) == &"" and sim.execute(
					PlaceBuildingCommand.new(def.id, o, phase == 0, item[3])) == &"":
				for placed: BuildingState in sim.province.buildings.all():
					if placed.origin == o and placed.def == def:
						b = placed
				break
		if b == null:
			print("m7: could not place ", item)
			continue
		if phase > 0:
			var site := sim.province.sites.get(b.site_id) as ConstructionSite
			if site != null:
				site.phase = mini(phase, site.phase_count())
			continue
		b.ensure_yard(sim.data)
		if b.yard != null:
			if def.herd_good != &"":
				b.yard.add(def.herd_good, 999)
			for good: StringName in BuildingState.yard_goods(def, sim.data):
				b.yard.add(good, 999)
		if b.stock != null:
			for good: StringName in [&"spear", &"bow", &"sword", &"chainmail"]:
				b.stock.add(good, 10)
	var view: ProvinceView = _game.get("view")
	view.piles.update_yards(sim.province.buildings)


## A barracks with 16 soldiers in the ranks and an armoury beside it (--m7=army).
func _place_army(sim: Simulation, at: Vector2i) -> void:
	var barracks := _place_near(sim, &"barracks", at)
	var armoury := _place_near(sim, &"armoury", at + Vector2i(-5, 0))
	if barracks == null:
		return
	if armoury != null:
		for good: StringName in [&"spear", &"bow", &"sword", &"chainmail"]:
			armoury.stock.add(good, 8)
	# --m7=army2 (J1 part 1): the new units instead.
	var kinds: Array[StringName] = [&"spearman", &"archer", &"swordsman", &"knight"]
	if _m7 == "army2":
		kinds = [&"halberdier", &"crossbowman", &"man_at_arms", &"light_cavalry"]
	# --m7=army3 (soldier rework, batch 2): the riders and the ladderman beside foot soldiers.
	if _m7 == "army3":
		kinds = [&"knight", &"light_cavalry", &"ladderman", &"halberdier"]
	for k: int in 16:
		var unit_id: StringName = kinds[k / 4]
		var unit := sim.data.get_unit(unit_id)
		var agent := sim.province.spawn_agent(unit_id, barracks.entrance_tile())
		agent.home_id = barracks.id
		agent.combat = CombatState.new(unit.combat.hp)
		barracks.soldiers.append(agent.id)
	# Into the ranks (and up to the drill if asked); the game reads the events afterwards.
	Game.paused = false
	sim.run_ticks(400)
	while Barracks.drilling(sim.clock.tick) != _drill:
		sim.run_ticks(1)
	sim.run_ticks(12 if _drill else 0)
	Game.paused = true
	(_game.get("camera") as GameCamera).position = IsoMath.tile_center_screen(barracks.entrance_tile() + Vector2i(1, 2))


## J1 part 2 (--m7=ballista [--raid_seconds=<s>]): two ballistas of the kingdom shooting at
## bandits and a ram coming at them; bolts in the air.
func _place_ballistas(sim: Simulation, at: Vector2i) -> void:
	var spawn := func(kind: StringName, tile: Vector2i, faction: int) -> Agent:
		var agent := sim.province.spawn_agent(kind, tile)
		agent.combat = CombatState.new(sim.data.get_unit(kind).combat.hp)
		agent.combat.unit = kind
		agent.combat.faction = faction
		Troops.take_command(agent)
		agent.combat.order = CombatState.Order.MOVE
		agent.combat.post = agent.pos
		agent.combat.goal = agent.pos
		agent.combat.stance = CombatState.Stance.HOLD
		return agent
	spawn.call(&"ballista", at + Vector2i(0, 0), CombatState.PLAYER)
	spawn.call(&"ballista", at + Vector2i(2, 1), CombatState.PLAYER)
	spawn.call(&"crossbowman", at + Vector2i(1, -1), CombatState.PLAYER)
	spawn.call(&"halberdier", at + Vector2i(3, -1), CombatState.PLAYER)
	spawn.call(&"ram", at + Vector2i(8, 6), CombatState.BANDITS)
	for k: int in 4:
		var bandit: Agent = spawn.call(&"spearman", at + Vector2i(7 + k % 2, 2 + k), CombatState.BANDITS)
		bandit.kind = &"bandit"
	Game.paused = false
	sim.run_ticks(SimClock.seconds_to_ticks(_raid_seconds))
	Game.paused = true
	(_game.get("camera") as GameCamera).position = IsoMath.tile_center_screen(at + Vector2i(4, 3))


## M7 part 3 (--map=coast --m7=fleet): two warships at anchor in deep water near --tile.
func _place_fleet(sim: Simulation, at: Vector2i) -> void:
	var def := sim.data.get_ship(&"warship")
	for k: int in 2:
		var ship := ShipUnit.new(sim.ids.take(), def, IsoMath.tile_center(at), sim.data)
		var spot := Voyage.anchorage(sim.province, ship, at + Vector2i(k * 6, k * 3))
		if spot == Agent.NO_TILE:
			continue
		ship.pos = IsoMath.tile_center(spot)
		ship.prev_pos = ship.pos
		ship.facing = 3 + k * 2
		sim.province.ships[ship.id] = ship


## M7 part 3 (--world --m7=siege [--siege=<id>] [--raid_seconds=<s>]): the player's army waits at
## a neutral settlement (Iron Wold, or Horse Haven with --siege=horse_haven) and goes in to
## fight; its men break what stands in the way to the town hall for a few seconds; the camera
## looks at the gate (or at --focus).
func _place_siege(sim: Simulation) -> void:
	var target := sim.world.id_of(_siege)
	var army := Army.new()
	army.id = sim.ids.take()
	army.at = target
	army.home = sim.viewed_id
	army.state = Army.State.WAITING
	army.units = {&"swordsman": 16, &"spearman": 8, &"archer": 8, &"ram": 1, &"ladderman": 2}
	army.food = army.food_cap()
	sim.world.armies[army.id] = army
	sim.execute(ArmySiegeCommand.new(army.id, ArmySiegeCommand.ENTER))
	_game.call("_show_province")
	var p := sim.province
	var gate: BuildingState = null
	for b: BuildingState in p.buildings.all():
		if b.def.is_gatehouse():
			gate = b
	var mine: Array[int] = []
	for agent: Agent in p.agents.all():
		if agent.combat != null and agent.combat.army == army.id:
			mine.append(agent.id)
	sim.execute(OrderTroopsCommand.new(mine, OrderTroopsCommand.BREAK, p.seat().entrance_tile()))
	Game.paused = false
	sim.run_ticks(SimClock.seconds_to_ticks(_raid_seconds))
	Game.paused = true
	var camera: GameCamera = _game.get("camera")
	var look := gate.entrance_tile() if gate != null else p.seat().entrance_tile()
	var sum := Vector2.ZERO
	var count := 0
	for id: int in mine:
		var agent := p.agents.get_agent(id)
		if agent != null:
			sum += agent.pos
			count += 1
	if count > 0:
		look = Vector2i((sum / count).floor())
	camera.position = IsoMath.tile_center_screen(look)
	(_game.get("view") as ProvinceView).forts.refresh()
	(_game.get("view") as ProvinceView).buildings.refresh_all()


## M7 part 2 (--m7=walls): a walled square with a gatehouse, towers, stairs, a thick double
## row, a diagonal run, a palisade and a wall being laid.
func _place_walls(sim: Simulation, at: Vector2i) -> void:
	var p := sim.province
	var stone := func(tiles: Array[Vector2i]) -> void:
		for t: Vector2i in tiles:
			if p.wall_error(t, Walls.STONE) == &"":
				p.lay_wall(t, Walls.STONE)
	var o := at + Vector2i(-7, -7)
	if p.execute_place(&"gatehouse", o + Vector2i(5, 11), 0) == null:
		print("walls: no gatehouse")
	p.execute_place(&"tower", o + Vector2i(-1, -1), 0)
	p.execute_place(&"tower", o + Vector2i(13, -1), 0)
	p.execute_place(&"tower", o + Vector2i(13, 11), 0)
	var ring: Array[Vector2i] = []
	for i: int in range(1, 13):
		ring.append(o + Vector2i(i, 0))
		ring.append(o + Vector2i(i, 1))   # a thick double row at the back
		ring.append(o + Vector2i(0, i))
		ring.append(o + Vector2i(14, i))
		ring.append(o + Vector2i(i, 12))
	stone.call(ring)
	stone.call(BuildWallCommand.line(o + Vector2i(-1, 12), o + Vector2i(-6, 17)))
	for t: Vector2i in [o + Vector2i(1, 5), o + Vector2i(13, 7)]:
		var d := p.stairs_dir_for(t)
		if d >= 0 and p.wall_error(t, Walls.STAIRS) == &"":
			p.lay_wall(t, Walls.STAIRS + d)
	for t: Vector2i in BuildWallCommand.line(o + Vector2i(16, 3), o + Vector2i(16, 10)):
		if p.wall_error(t, Walls.PALISADE) == &"":
			p.lay_wall(t, Walls.PALISADE)
	for t: Vector2i in BuildWallCommand.line(o + Vector2i(17, 10), o + Vector2i(20, 13)):
		if p.wall_error(t, Walls.PALISADE) == &"":
			p.lay_wall(t, Walls.PALISADE)
	# A turned gatehouse in the west wall (its art has its own light, not a mirror).
	p.execute_place(&"gatehouse", o + Vector2i(-1, 7), 1)
	# A palisade gate in the straight palisade (M7 part 3).
	p.execute_place(&"palisade_gate", o + Vector2i(16, 6), 0)
	p.damage_wall(o + Vector2i(14, 4), 700)
	sim.execute(BuildWallCommand.new(BuildWallCommand.line(o + Vector2i(2, 16), o + Vector2i(8, 16)), Walls.STONE))
	for k: int in 6:
		var a := p.spawn_agent(&"porter", o + Vector2i(6, 13 + k % 3))
		a.facing = k % 8
	sim.events.drain()
	(_game.get("view") as ProvinceView).forts.refresh()
	(_game.get("view") as ProvinceView).buildings.refresh_all()


## M7 part 2 (--m7=battle): archers on the walls, spearmen behind the gate, enemies coming
## at them; a few seconds of fighting, the archers selected.
func _place_battle(sim: Simulation, at: Vector2i) -> void:
	var p := sim.province
	var o := at + Vector2i(-7, -7)
	var spawn := func(kind: StringName, tile: Vector2i, faction: int) -> Agent:
		var a := p.spawn_agent(kind, tile)
		a.combat = CombatState.new(sim.data.get_unit(kind).combat.hp)
		a.combat.faction = faction
		Troops.take_command(a)
		a.combat.order = CombatState.Order.MOVE
		a.combat.post = a.pos
		a.combat.goal = a.pos
		return a
	var archers: Array[Agent] = []
	for k: int in 6:
		archers.append(spawn.call(&"archer", o + Vector2i(6, 6), CombatState.PLAYER))
	Troops.order_move(p, archers, o + Vector2i(4, 12), MilitaryNav.WALL)
	var archers2: Array[Agent] = []
	for k: int in 4:
		archers2.append(spawn.call(&"archer", o + Vector2i(8, 6), CombatState.PLAYER))
	Troops.order_move(p, archers2, o + Vector2i(14, 8), MilitaryNav.WALL)
	var guards: Array[Agent] = []
	for k: int in 6:
		guards.append(spawn.call(&"spearman", o + Vector2i(6, 8), CombatState.PLAYER))
	Troops.order_move(p, guards, o + Vector2i(6, 9), MilitaryNav.GROUND)
	for k: int in 8:
		var e: Agent = spawn.call(&"spearman" if k % 3 != 0 else &"archer", o + Vector2i(2 + k, 20 + k % 3), CombatState.BANDITS)
		e.combat.stance = CombatState.Stance.AGGRESSIVE
	Game.paused = false
	for i: int in 220:
		sim.step()
	Game.paused = true
	var view: ProvinceView = _game.get("view")
	for event: Dictionary in sim.events.drain():
		view.on_sim_event(event)
	for a: Agent in guards + archers:
		if p.agents.has_agent(a.id):
			print("battle: %s %s level %d hp %d order %d" % [a.kind, a.pos, a.level, a.combat.hp, a.combat.order])
	var ids: Array[int] = []
	for a: Agent in archers:
		if p.agents.has_agent(a.id):
			ids.append(a.id)
	_game.call("_select_soldiers", ids)


## M7 part 2 (--m7=raid): a bandit raid with a ram and laddermen on the walled square, the
## archers on the walls; --advance-like run of [_raid_seconds] seconds (default 25).
func _place_raid(sim: Simulation, at: Vector2i) -> void:
	var p := sim.province
	var o := at + Vector2i(-7, -7)
	for b: BuildingState in p.buildings.all().duplicate():
		if b.def.id == &"town_hall" or b.def.id == &"pioneer_camp":
			p.remove_building(b.id)   # the hall of this shot stands inside the walls
	p.first_building = &""
	var hall := p.execute_place(&"town_hall", o + Vector2i(5, 3), 0)
	if hall == null:
		print("raid: no town hall")
	var archers: Array[Agent] = []
	for k: int in 8:
		var a := p.spawn_agent(&"archer", o + Vector2i(6, 8))
		a.combat = CombatState.new(sim.data.get_unit(&"archer").combat.hp)
		archers.append(a)
	Troops.order_move(p, archers, o + Vector2i(9, 12), MilitaryNav.WALL)
	for k: int in 30:
		sim.step()
	p.raids.entry = o + Vector2i(6, 24)
	p.raids.count = Raids.RAM_EVERY - 1   # the big one, with a ram
	Raids.start(p, sim.rng.stream(&"raids"))
	sim.raids_enabled = true
	Game.paused = false
	for i: int in roundi(_raid_seconds * SimClock.TICKS_PER_SECOND):
		sim.step()
	Game.paused = true
	var view: ProvinceView = _game.get("view")
	for event: Dictionary in sim.events.drain():
		view.on_sim_event(event)
	view.forts.refresh()
	view.buildings.refresh_all()


## M8 part 4 (--map=lakeland --m7=storm [--raid_seconds=<s>]): an AI ruler's army (made up for
## the picture) storms the player's walled town live, as a raid would.
func _place_storm(sim: Simulation, at: Vector2i) -> void:
	var p := sim.province
	var o := at + Vector2i(-7, -7)
	for b: BuildingState in p.buildings.all().duplicate():
		if b.def.id == &"town_hall" or b.def.id == &"pioneer_camp":
			p.remove_building(b.id)
	p.first_building = &""
	if p.execute_place(&"town_hall", o + Vector2i(5, 3), 0) == null:
		print("storm: no town hall")
	var defenders: Array[Agent] = []
	for k: int in 6:
		var a := p.spawn_agent(&"archer" if k % 2 == 0 else &"spearman", o + Vector2i(6, 8))
		a.combat = CombatState.new(sim.data.get_unit(a.kind).combat.hp)
		defenders.append(a)
	Troops.order_move(p, defenders, o + Vector2i(9, 12), MilitaryNav.WALL)
	for k: int in 30:
		sim.step()
	var near := 0
	if not sim.world.is_single():
		var wold := sim.world.id_of(&"iron_wold")
		for id: int in sim.world.ids():
			if near == 0 and id != wold and not sim.runtimes.has(id) and sim.world.are_neighbours(id, wold, sim.data):
				near = id
		sim.open_province(near, sim.data.get_map(sim.world.get_province(near).map_id), &"ruler_1")
		RulerPlanner.ensure_rulers(sim)
	var army := Army.new()
	army.id = sim.ids.take()
	army.owner = &"ruler_1"
	army.at = sim.viewed_id
	army.home = near
	army.state = Army.State.IDLE
	army.pos = ArmyOrders.stand_point(sim, sim.viewed_id)
	army.units = {&"knight": 4, &"swordsman": 6, &"crossbowman": 4, &"halberdier": 4, &"ladderman": 2, &"ram": 1}
	army.food = army.food_cap()
	sim.world.armies[army.id] = army
	p.raids.entry = o + Vector2i(6, 24)
	RulerWar.assault(sim, army)
	Game.paused = false
	for i: int in roundi(_raid_seconds * SimClock.TICKS_PER_SECOND):
		sim.step()
	Game.paused = true
	var view: ProvinceView = _game.get("view")
	for event: Dictionary in sim.events.drain():
		view.on_sim_event(event)
	view.forts.refresh()
	view.buildings.refresh_all()


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
## B1 part 2: each building of --stilts placed nearest [param at] where it leans one row over
## the water on piles, finished.
func _place_stilts(sim: Simulation, at: Vector2i) -> void:
	Game.paused = true
	var province := sim.province
	province.first_building = &""
	for id_text: String in _stilts:
		var id := StringName(id_text)
		var def := sim.data.get_building(id)
		var placed := false
		for r: int in 24:
			for y: int in range(at.y - r, at.y + r + 1):
				for x: int in range(at.x - r, at.x + r + 1):
					if placed or maxi(absi(x - at.x), absi(y - at.y)) != r:
						continue
					var origin := Vector2i(x, y)
					if province.stilt_tiles(def, origin).is_empty():
						continue
					for o: int in def.orientation_count():
						if not placed and province.placement_error(def, origin, o) == &"":
							placed = sim.execute(PlaceBuildingCommand.new(id, origin, true, o)) == &""
							if placed:
								print("stilts ", id, " at ", origin, " turn ", o)
		if not placed:
			print("stilts ", id, ": no place")
	var view: ProvinceView = _game.get("view")
	view.quays.refresh()
	view.buildings.refresh_all()


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
