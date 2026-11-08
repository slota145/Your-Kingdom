extends GdUnitTestSuite
## B1 part 1: timber and stone bridges over a river, ford or lake, dragged from bank to bank in
## 8 directions, laid by a builder from the near bank; people walk over them and wagons drive
## over them; the whole bridge comes down at once; saved from v21.


## 48x48: a river 4 tiles wide (columns 20-23) from top to bottom; a village west of it with
## planks and stone in store.
func _river_sim() -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	var water := SimFixture.registry().get_terrain(&"water")
	for y: int in sim.province.grid.size.y:
		for x: int in range(20, 24):
			sim.province.grid.set_terrain(Vector2i(x, y), water.index)
	sim.province.rebuild_nav()
	var village := SimFixture.village(sim, 40, 20)
	var stock: BuildingState = village["stock"]
	stock.stock.add(&"planks", 30)
	stock.stock.add(&"stone", 30)
	sim.treasury.gold = 500
	return sim


## Lays a bridge at once (the builder's work is tested on its own).
func _lay(sim: Simulation, from: Vector2i, to: Vector2i, kind: int = TileGrid.TIMBER_BRIDGE) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	tiles.assign(sim.province.bridge_plan(from, to)["tiles"])
	for tile: Vector2i in tiles:
		sim.province.grid.set_bridge(tile, kind)
		sim.province.refresh_tile(tile)
	return tiles


func test_builder_lays_a_timber_bridge_from_the_near_bank() -> void:
	var sim := _river_sim()
	var province := sim.province
	assert_array(province.find_path(Vector2i(18, 10), Vector2i(26, 10))).is_empty()
	assert_str(String(sim.execute(BuildBridgeCommand.new(Vector2i(17, 10), Vector2i(26, 10))))).is_empty()
	var site: PavingSite = province.paving.values()[0]
	assert_bool(site.is_bridge()).is_true()
	# From a ramp on the near bank over the water to a ramp on the far bank.
	assert_array(site.tiles).is_equal([Vector2i(19, 10), Vector2i(20, 10), Vector2i(21, 10), Vector2i(22, 10),
			Vector2i(23, 10), Vector2i(24, 10)])
	var planks_before := province.stored(&"planks")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.paving.is_empty(), 300)).is_true()
	for x: int in range(19, 25):
		assert_int(province.grid.bridge(Vector2i(x, 10))).is_equal(TileGrid.TIMBER_BRIDGE)
		assert_bool(province.nav.is_walkable(Vector2i(x, 10))).is_true()
	assert_int(planks_before - province.stored(&"planks")).is_equal(18)
	assert_float(province.nav.get_cost(Vector2i(21, 10))).is_equal_approx(ProvinceSim.ROAD_COST, 0.001)
	assert_array(province.find_path(Vector2i(18, 10), Vector2i(26, 10))).is_not_empty()
	assert_int(province.claim_count()).is_equal(0)


func test_stone_bridge_costs_stone_and_walks_like_paving() -> void:
	var sim := _river_sim()
	var province := sim.province
	assert_str(String(sim.execute(BuildBridgeCommand.new(Vector2i(19, 12), Vector2i(24, 12), TileGrid.STONE_BRIDGE)))).is_empty()
	var stone_before := province.stored(&"stone")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.paving.is_empty(), 300)).is_true()
	assert_int(stone_before - province.stored(&"stone")).is_equal(24)
	assert_int(province.grid.bridge(Vector2i(22, 12))).is_equal(TileGrid.STONE_BRIDGE)
	assert_float(province.nav.get_cost(Vector2i(22, 12))).is_equal_approx(ProvinceSim.PAVED_COST, 0.001)


func test_wagons_drive_over_a_bridge() -> void:
	var sim := _river_sim()
	var province := sim.province
	var road: Array[Vector2i] = []
	for x: int in range(14, 20):
		road.append(Vector2i(x, 20))
	for x: int in range(24, 30):
		road.append(Vector2i(x, 20))
	assert_str(String(sim.execute(BuildRoadCommand.new(road)))).is_empty()
	assert_array(province.find_road_path(Vector2i(14, 20), Vector2i(29, 20))).is_empty()
	_lay(sim, Vector2i(19, 20), Vector2i(24, 20))
	var path := province.find_road_path(Vector2i(14, 20), Vector2i(29, 20))
	assert_array(path).is_not_empty()
	assert_array(path).contains([Vector2i(21, 20)])


func test_diagonal_bridge_has_wedges_and_people_cross_it() -> void:
	var sim := _river_sim()
	var province := sim.province
	var plan := province.bridge_plan(Vector2i(18, 10), Vector2i(25, 17))
	assert_str(String(plan["error"])).is_empty()
	var tiles: Array = plan["tiles"]
	# 4 steps over the water, a ramp on each bank and both wedges beside every step.
	assert_int(tiles.size()).is_equal(16)
	# Laid from the near bank: the ramp first, each step after its wedges, the far ramp last.
	assert_that(tiles[0]).is_equal(Vector2i(19, 11))
	assert_that(tiles[1]).is_equal(Vector2i(20, 11))
	assert_that(tiles[3]).is_equal(Vector2i(20, 12))
	assert_that(tiles[tiles.size() - 1]).is_equal(Vector2i(24, 16))
	_lay(sim, Vector2i(18, 10), Vector2i(25, 17))
	var path := province.find_path(Vector2i(19, 11), Vector2i(24, 16))
	assert_array(path).is_not_empty()
	assert_int(path.size()).is_less_equal(7)


func test_ramps_go_on_to_the_land_and_cut_a_tree_there() -> void:
	var sim := _river_sim()
	var province := sim.province
	SimFixture.plant_trees(sim, Rect2i(24, 18, 1, 1))
	assert_bool(province.resources.has_node(Vector2i(24, 18))).is_true()
	assert_str(String(sim.execute(BuildBridgeCommand.new(Vector2i(19, 18), Vector2i(25, 18))))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.paving.is_empty(), 300)).is_true()
	assert_int(province.grid.bridge(Vector2i(19, 18))).is_equal(TileGrid.TIMBER_BRIDGE)
	assert_int(province.grid.bridge(Vector2i(24, 18))).is_equal(TileGrid.TIMBER_BRIDGE)
	assert_bool(province.resources.has_node(Vector2i(24, 18))).is_false()
	# Nothing is built, planted or laid as road on a ramp.
	assert_str(String(province.road_error(Vector2i(19, 18)))).is_equal("tile_occupied")
	assert_bool(province.can_plant(Vector2i(19, 18))).is_false()
	# A ramp cannot go on to a building.
	SimFixture.place(sim, &"woodcutter", Vector2i(24, 22))
	assert_str(String(province.bridge_plan(Vector2i(19, 22), Vector2i(26, 22))["error"])).is_not_empty()


func test_bridge_needs_both_banks_and_at_most_eight_tiles_of_water() -> void:
	var sim := _river_sim()
	var province := sim.province
	# Ends in the water.
	assert_str(String(province.bridge_plan(Vector2i(19, 5), Vector2i(22, 5))["error"])).is_equal("bridge_needs_far_bank")
	# Starts in the water.
	assert_str(String(province.bridge_plan(Vector2i(20, 5), Vector2i(25, 5))["error"])).is_equal("bridge_needs_bank")
	# No water at all.
	assert_str(String(province.bridge_plan(Vector2i(10, 30), Vector2i(15, 30))["error"])).is_equal("no_water")
	# A wide river: 10 tiles of water.
	var water := SimFixture.registry().get_terrain(&"water")
	for x: int in range(24, 30):
		for y: int in range(30, 34):
			province.grid.set_terrain(Vector2i(x, y), water.index)
	province.rebuild_nav()
	assert_str(String(province.bridge_plan(Vector2i(19, 31), Vector2i(31, 31))["error"])).is_equal("bridge_too_long")
	assert_str(String(sim.execute(BuildBridgeCommand.new(Vector2i(19, 31), Vector2i(31, 31))))).is_equal("bridge_too_long")
	# No bridge on the sea (quays are for the sea).
	SimFixture.coast(sim, 40, 44)
	assert_bool(province.is_bridgeable(Vector2i(10, 42))).is_false()


func test_bridge_over_a_ford_and_a_lake() -> void:
	var sim := _river_sim()
	var province := sim.province
	var ford := SimFixture.registry().get_terrain(&"ford")
	var lake := SimFixture.registry().get_terrain(&"lake")
	for x: int in range(20, 24):
		province.grid.set_terrain(Vector2i(x, 25), ford.index)
		province.grid.set_terrain(Vector2i(x, 35), lake.index)
	province.rebuild_nav()
	assert_str(String(province.bridge_plan(Vector2i(19, 25), Vector2i(24, 25))["error"])).is_empty()
	assert_str(String(province.bridge_plan(Vector2i(19, 35), Vector2i(24, 35))["error"])).is_empty()
	# Wagons need the bridge over a ford: roads cannot be laid on it.
	_lay(sim, Vector2i(19, 25), Vector2i(24, 25))
	assert_bool(province.road_nav.is_walkable(Vector2i(21, 25))).is_true()


func test_whole_bridge_comes_down_but_not_under_people() -> void:
	var sim := _river_sim()
	var province := sim.province
	_lay(sim, Vector2i(19, 8), Vector2i(24, 8))
	var walker := SimFixture.spawn(sim, &"porter", Vector2i(22, 8))
	assert_str(String(sim.execute(RemoveBridgeCommand.new(Vector2i(21, 8))))).is_equal("tile_has_people")
	province.agents.remove(walker.id)
	assert_str(String(sim.execute(RemoveBridgeCommand.new(Vector2i(21, 8))))).is_empty()
	assert_int(province.grid.bridge_count()).is_equal(0)
	assert_bool(province.nav.is_walkable(Vector2i(22, 8))).is_false()
	assert_str(String(sim.execute(RemoveBridgeCommand.new(Vector2i(21, 8))))).is_equal("no_bridge")


func test_ordered_bridge_can_be_cancelled() -> void:
	var sim := _river_sim()
	var province := sim.province
	assert_str(String(sim.execute(BuildBridgeCommand.new(Vector2i(19, 14), Vector2i(24, 14))))).is_empty()
	assert_int(province.bridge_site_at(Vector2i(22, 14))).is_not_equal(0)
	# Not cancelled as cobbles.
	assert_str(String(province.cancel_paving_error(Vector2i(22, 14)))).is_equal("not_paving")
	assert_str(String(sim.execute(RemoveBridgeCommand.new(Vector2i(22, 14))))).is_empty()
	assert_bool(province.paving.is_empty()).is_true()
	# A second order over the same water is refused while the first stands.
	assert_str(String(sim.execute(BuildBridgeCommand.new(Vector2i(19, 15), Vector2i(24, 15))))).is_empty()
	assert_str(String(sim.execute(BuildBridgeCommand.new(Vector2i(19, 15), Vector2i(24, 15))))).is_equal("already_ordered")


func test_bridges_and_bridge_orders_survive_a_save() -> void:
	var sim := _river_sim()
	_lay(sim, Vector2i(19, 8), Vector2i(24, 8), TileGrid.STONE_BRIDGE)
	assert_str(String(sim.execute(BuildBridgeCommand.new(Vector2i(19, 14), Vector2i(24, 14))))).is_empty()
	var state := sim.to_dict()
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(copy.province.grid.bridge(Vector2i(21, 8))).is_equal(TileGrid.STONE_BRIDGE)
	assert_bool(copy.province.nav.is_walkable(Vector2i(21, 8))).is_true()
	assert_bool((copy.province.paving.values()[0] as PavingSite).is_bridge()).is_true()


## v20 saves (and older) load as v21 with an empty layer of bridges.
func test_older_save_migrates_to_v21_without_bridges() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v16_crane.json"))
	var state := SaveMigrations.migrate(document["state"], 16)
	var grid: Dictionary = ((state["provinces"] as Array)[0] as Dictionary)["state"]["grid"]
	assert_bool(grid.has("bridges")).is_true()
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(sim.province.grid.bridge_count()).is_equal(0)
	assert_int(SaveMigrations.CURRENT_VERSION).is_equal(21)


## On the "Coast" the river cuts the east of the map off but for its fords: a bridge shortens
## the way across (DoD B1).
func test_bridge_shortens_the_way_east_on_the_coast() -> void:
	var registry := SimFixture.registry()
	var problems := PackedStringArray()
	var sim := Simulation.from_map(registry, registry.get_map(&"coast"), 1, problems)
	var province := sim.province
	var from := Vector2i(54, 35)
	var to := Vector2i(66, 35)
	var before := province.find_path(from, to)
	assert_array(before).is_not_empty()
	var plan := province.bridge_plan(Vector2i(57, 35), Vector2i(62, 35))
	assert_str(String(plan["error"])).is_empty()
	_lay(sim, Vector2i(57, 35), Vector2i(62, 35))
	var after := province.find_path(from, to)
	assert_int(after.size()).is_less(before.size() - 5)


## What the game does when a road or cobbles are dragged over a river (B1, owner's request
## 2026-11-08): a bridge over each crossing, then the road on the land around it.
func _drag_road(sim: Simulation, path: Array[Vector2i], paving: bool) -> void:
	var tiles := path.duplicate()
	var bridge := TileGrid.STONE_BRIDGE if paving else TileGrid.TIMBER_BRIDGE
	for crossing: Dictionary in sim.province.road_crossings(tiles):
		if (crossing["plan"] as Dictionary)["error"] == &"":
			assert_str(String(sim.execute(BuildBridgeCommand.new(crossing["from"], crossing["to"], bridge)))).is_empty()
			tiles.append_array(crossing["link"])
	var road: Array[Vector2i] = []
	for t: Vector2i in tiles:
		if (sim.province.paving_error(t) if paving else sim.province.road_error(t)) == &"":
			road.append(t)
	if paving:
		sim.execute(BuildPavingCommand.new(road))
	else:
		sim.execute(BuildRoadCommand.new(road))


## A 4-step path like the road tool's drag.
func _drag_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = [from]
	var last := from
	while last != to:
		var d := to - last
		if absi(d.x) >= absi(d.y):
			last.x += signi(d.x)
		else:
			last.y += signi(d.y)
		tiles.append(last)
	return tiles


func test_road_over_a_river_brings_a_timber_bridge_and_cobbles_a_stone_one() -> void:
	var sim := _river_sim()
	var province := sim.province
	_drag_road(sim, _drag_path(Vector2i(14, 26), Vector2i(29, 26)), false)
	assert_int(province.bridge_site_at(Vector2i(21, 26))).is_not_equal(0)
	_drag_road(sim, _drag_path(Vector2i(14, 30), Vector2i(29, 30)), true)
	var stone_site := province.paving[province.bridge_site_at(Vector2i(21, 30))] as PavingSite
	assert_int(stone_site.bridge_value()).is_equal(TileGrid.STONE_BRIDGE)
	# A slanting drag: the bridge goes straight and a short road leads back to the drag.
	_drag_road(sim, _drag_path(Vector2i(14, 36), Vector2i(29, 39)), false)
	# Lay the ordered bridges and cobbles at once (the building itself is tested above).
	for site: PavingSite in province.paving.values():
		for tile: Vector2i in site.tiles:
			if site.is_bridge():
				province.grid.set_bridge(tile, site.bridge_value())
			else:
				province.grid.set_paved(tile, true)
			province.refresh_tile(tile)
	for row: int in [26, 30]:
		assert_int(province.grid.bridge(Vector2i(19, row))).is_not_equal(0)
		assert_array(province.find_road_path(Vector2i(14, row), Vector2i(29, row))).is_not_empty()
	assert_array(province.find_road_path(Vector2i(14, 36), Vector2i(29, 39))).is_not_empty()
	# Dragging the road again over a bridge brings no second one.
	assert_array(province.road_crossings(_drag_path(Vector2i(14, 26), Vector2i(29, 26)))).is_empty()
