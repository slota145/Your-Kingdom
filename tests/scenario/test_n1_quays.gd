extends GdUnitTestSuite
## N1 part 1: timber piers and stone quays laid on the sea by a builder from the shore
## outwards; people walk on them, ships do not; a quay may not reach further than 8 tiles from
## the shore nor cut a berth, a shoal or a ship off the open sea; a mooring on the quay takes
## a second ship, loaded and unloaded by the dockers of a nearby port.


## 48x48: land above row 30, shallow sea rows 30-32, deep sea from row 33. A village with a
## storage of planks and stone.
func _coast_sim() -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	var village := SimFixture.village(sim, 40, 20)
	var stock: BuildingState = village["stock"]
	stock.stock.add(&"planks", 30)
	stock.stock.add(&"stone", 30)
	sim.treasury.gold = 500
	return sim


func _column(x: int, from_y: int, to_y: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y: int in range(from_y, to_y + 1):
		tiles.append(Vector2i(x, y))
	return tiles


## Lays quay at once (the builder's work is tested on its own).
func _lay(sim: Simulation, tiles: Array[Vector2i], quay: int = TileGrid.PIER) -> void:
	for tile: Vector2i in tiles:
		sim.province.grid.set_quay(tile, quay)
		sim.province.refresh_tile(tile)
	sim.province.refresh_fairways()


func test_builder_lays_a_pier_from_the_shore_outwards() -> void:
	var sim := _coast_sim()
	var province := sim.province
	var pier := _column(12, 30, 33)
	# Ordered from the sea end: the builder still lays it from the shore.
	pier.reverse()
	assert_str(String(sim.execute(BuildQuayCommand.new(pier, TileGrid.PIER)))).is_empty()
	var site: PavingSite = province.paving.values()[0]
	assert_bool(site.is_quay()).is_true()
	assert_array(site.tiles).is_equal(_column(12, 30, 33))
	# Ships keep off the ordered tiles at once.
	assert_bool(province.boat_nav.is_walkable(Vector2i(12, 33))).is_false()
	var planks_before := province.stored(&"planks")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.paving.is_empty(), 240)).is_true()
	for tile: Vector2i in _column(12, 30, 33):
		assert_int(province.grid.quay(tile)).is_equal(TileGrid.PIER)
		assert_bool(province.nav.is_walkable(tile)).is_true()
		assert_bool(province.boat_nav.is_walkable(tile)).is_false()
		assert_bool(province.cog_nav.is_walkable(tile)).is_false()
	assert_int(planks_before - province.stored(&"planks")).is_equal(8)
	# A pier is walked on like a road.
	assert_float(province.nav.get_cost(Vector2i(12, 31))).is_equal_approx(ProvinceSim.ROAD_COST, 0.001)
	assert_int(province.claim_count()).is_equal(0)


func test_stone_quay_costs_stone_and_walks_like_paving() -> void:
	var sim := _coast_sim()
	var province := sim.province
	assert_str(String(sim.execute(BuildQuayCommand.new(_column(14, 30, 31), TileGrid.STONE_QUAY)))).is_empty()
	var stone_before := province.stored(&"stone")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.paving.is_empty(), 240)).is_true()
	assert_int(stone_before - province.stored(&"stone")).is_equal(6)
	assert_int(province.grid.quay(Vector2i(14, 31))).is_equal(TileGrid.STONE_QUAY)
	assert_float(province.nav.get_cost(Vector2i(14, 31))).is_equal_approx(ProvinceSim.PAVED_COST, 0.001)


func test_quay_reaches_at_most_eight_tiles_from_the_shore() -> void:
	var sim := _coast_sim()
	var plan := sim.province.quay_plan(_column(16, 30, 39))
	assert_int((plan["tiles"] as Array).size()).is_equal(8)
	var errors: Dictionary = plan["errors"]
	assert_str(String(errors[Vector2i(16, 38)])).is_equal("too_far_from_shore")
	assert_str(String(errors[Vector2i(16, 39)])).is_equal("too_far_from_shore")
	# Not joined to the shore nor to any quay.
	plan = sim.province.quay_plan(_column(20, 34, 35))
	assert_array(plan["tiles"]).is_empty()
	assert_str(String((plan["errors"] as Dictionary)[Vector2i(20, 34)])).is_equal("not_at_shore")
	assert_str(String(sim.province.quay_error(Vector2i(16, 20)))).is_equal("needs_sea")
	# A quay grows on from an older one: its reach counts from the shore.
	_lay(sim, _column(16, 30, 33))
	plan = sim.province.quay_plan(_column(16, 34, 38))
	assert_int((plan["tiles"] as Array).size()).is_equal(4)


func test_quay_may_not_cut_a_berth_off_the_sea() -> void:
	var sim := _coast_sim()
	var port := SimFixture.place(sim, &"port", Vector2i(20, 28))
	assert_vector(port.berth_tile()).is_equal(Vector2i(22, 32))
	assert_str(String(sim.province.quay_error(port.berth_tile()))).is_equal("keeps_berth")
	var ring: Array[Vector2i] = _column(19, 30, 33) + _column(24, 30, 33)
	for x: int in range(20, 24):
		ring.append(Vector2i(x, 33))
	assert_str(String(sim.execute(BuildQuayCommand.new(ring)))).is_equal("blocks_sea")
	# Leaving the way out to deep water open is fine.
	ring.erase(Vector2i(22, 33))
	assert_str(String(sim.execute(BuildQuayCommand.new(ring)))).is_empty()


func test_harbour_buildings_stand_on_the_quay() -> void:
	var sim := _coast_sim()
	var province := sim.province
	# A quay block in front of the shore: the port stands on it with its land part too.
	var block: Array[Vector2i] = []
	for y: int in range(30, 32):
		for x: int in range(26, 31):
			block.append(Vector2i(x, y))
	_lay(sim, block, TileGrid.STONE_QUAY)
	var port := sim.data.get_building(&"port")
	# Land rows on the quay, water rows on the sea.
	assert_str(String(province.placement_error(port, Vector2i(26, 30)))).is_empty()
	# Other buildings stay off the quay.
	assert_str(String(province.placement_error(sim.data.get_building(&"hut"), Vector2i(26, 30)))).is_equal("not_on_quay")


func test_mooring_takes_a_second_ship_served_by_port_dockers() -> void:
	var sim := _coast_sim()
	var province := sim.province
	var mooring_def := sim.data.get_building(&"mooring")
	_lay(sim, [Vector2i(10, 30), Vector2i(11, 30), Vector2i(10, 31), Vector2i(11, 31)])
	assert_str(String(province.placement_error(mooring_def, Vector2i(10, 30)))).is_equal("no_port_nearby")
	assert_str(String(province.placement_error(mooring_def, Vector2i(10, 26)))).is_equal("needs_quay")
	var port := SimFixture.place(sim, &"port", Vector2i(20, 28))
	for i: int in 2:
		var docker := SimFixture.spawn(sim, Harbour.DOCKER_KIND, port.entrance_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(docker.id, port.id)))).is_empty()
	assert_str(String(province.placement_error(mooring_def, Vector2i(10, 30)))).is_empty()
	var mooring := SimFixture.place(sim, &"mooring", Vector2i(10, 30))
	assert_vector(mooring.berth_tile()).is_equal(Vector2i(11, 32))
	assert_int(Harbour.crew_of(province, mooring)).is_equal(port.id)
	# The port's berth is taken: the sea merchant moors at the mooring.
	var cog := sim.data.get_ship(&"foreign_cog")
	var other := ShipUnit.new(province.ids.take(), cog, Vector2(30.5, 44.5), sim.data)
	province.ships[other.id] = other
	assert_bool(Harbour.claim_berth(province, other, port)).is_true()
	assert_str(String(sim.execute(SetSellAboveCommand.new(&"wood", 10)))).is_empty()
	var trader := province.sea_merchant
	trader.next_visit = province.tick + 10
	var traded := SimFixture.run_until(sim, func() -> bool: return trader.is_trading(), 200)
	assert_bool(traded).is_true()
	var ship := province.ships.get(trader.ship_id) as ShipUnit
	assert_vector(ship.tile()).is_equal(mooring.berth_tile())
	# Port dockers carry the wood aboard at the mooring.
	var sold := SimFixture.run_until(sim, func() -> bool: return ship.hold.total(&"wood") >= 10, 400)
	assert_bool(sold).is_true()


func test_quay_tiles_can_be_taken_away_but_not_cut_off() -> void:
	var sim := _coast_sim()
	var province := sim.province
	_lay(sim, _column(12, 30, 33))
	assert_str(String(province.remove_quay_error(Vector2i(12, 31)))).is_equal("cuts_quay")
	assert_str(String(sim.execute(RemoveQuayCommand.new(Vector2i(12, 33))))).is_empty()
	assert_bool(province.grid.has_quay(Vector2i(12, 33))).is_false()
	assert_bool(province.boat_nav.is_walkable(Vector2i(12, 33))).is_true()
	# An order not laid yet is taken back too.
	assert_str(String(sim.execute(BuildQuayCommand.new(_column(12, 33, 34))))).is_empty()
	assert_str(String(sim.execute(RemoveQuayCommand.new(Vector2i(12, 34))))).is_empty()
	var site: PavingSite = province.paving.values()[0]
	assert_array(site.tiles).is_equal([Vector2i(12, 33)])


func test_quay_survives_save_and_load() -> void:
	var sim := _coast_sim()
	_lay(sim, _column(12, 30, 31), TileGrid.STONE_QUAY)
	assert_str(String(sim.execute(BuildQuayCommand.new(_column(12, 32, 33))))).is_empty()
	sim.run_ticks(SimFixture.ticks(20))
	var copy := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())), sim.data)
	assert_int(copy.province.grid.quay(Vector2i(12, 31))).is_equal(TileGrid.STONE_QUAY)
	assert_int(copy.province.paving.size()).is_equal(sim.province.paving.size())
	var site: PavingSite = copy.province.paving.values()[0]
	assert_bool(site.is_quay()).is_true()
	assert_bool(copy.province.boat_nav.is_walkable(Vector2i(12, 33))).is_false()
	assert_bool(copy.province.nav.is_walkable(Vector2i(12, 31))).is_true()


## The v15 fixture (tools/build_quay_fixture.gd): loads unchanged, the pier being laid is
## finished, and the harbour stays reachable from the sea.
func test_v15_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v15_quays.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(15)
	var state := SaveMigrations.migrate(document["state"], 15)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var province := sim.province
	assert_int(province.grid.quay_count()).is_equal(17)
	assert_int(province.paving.size()).is_equal(1)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.paving.is_empty(), 300)).is_true()
	assert_int(province.grid.quay(Vector2i(12, 32))).is_equal(TileGrid.PIER)
	assert_array(Array(province.dangling_holds())).is_empty()


## A v14 game migrates to v15 with no quays; its harbour keeps working as before.
func test_v14_save_migrates_to_v15_without_quays() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v14_routes.json"))
	var state := SaveMigrations.migrate(document["state"], 14)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_int(sim.province.grid.quay_count()).is_equal(0)
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
