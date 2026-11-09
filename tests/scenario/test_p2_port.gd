extends GdUnitTestSuite
## P2 part 1: a bollard on a stone quay where a ship moors, its cargo going to the nearest port
## warehouse, or straight to the storages without one; port warehouses of three sizes without staff; houses of dockers whose dockers
## carry ship cargo and port goods within reach; harbour buildings up to 2 rows on piles.


## 48x48: land above row 30, shallow sea rows 30-32, deep from row 33. A stone quay strip
## (10..21, 30..31); a small port warehouse on land at (12, 27).
func _harbour_sim() -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	sim.treasury.gold = 500
	var province := sim.province
	for y: int in range(30, 32):
		for x: int in range(10, 22):
			province.grid.set_quay(Vector2i(x, y), TileGrid.STONE_QUAY)
			province.refresh_tile(Vector2i(x, y))
	province.refresh_fairways()
	var warehouse := SimFixture.place(sim, &"port_warehouse_small", Vector2i(12, 27))
	return {"sim": sim, "warehouse": warehouse}


## A house of dockers at [param origin] with its dockers at work.
func _docker_hut(sim: Simulation, origin: Vector2i) -> BuildingState:
	var hut := SimFixture.place(sim, &"docker_hut", origin)
	for i: int in hut.def.worker_count():
		var docker := SimFixture.spawn(sim, Harbour.DOCKER_KIND, hut.door_front_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(docker.id, hut.id)))).is_empty()
	return hut


## A cog moored at [param dock] with [param wood] wood in its hold.
func _cog_at(sim: Simulation, dock: BuildingState, wood: int) -> ShipUnit:
	var province := sim.province
	var ship := ShipUnit.new(province.ids.take(), sim.data.get_ship(&"foreign_cog"),
			IsoMath.tile_center(dock.berth_tile()), sim.data)
	province.ships[ship.id] = ship
	Harbour.moor(ship, dock)
	if wood > 0:
		ship.hold.add(&"wood", wood)
	return ship


func test_bollard_stands_on_a_stone_quay() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	var province := sim.province
	for x: int in range(10, 22):
		province.grid.set_quay(Vector2i(x, 31), TileGrid.STONE_QUAY if x < 16 else TileGrid.PIER)
		province.grid.set_quay(Vector2i(x, 30), TileGrid.STONE_QUAY if x < 16 else TileGrid.PIER)
		province.refresh_tile(Vector2i(x, 31))
		province.refresh_tile(Vector2i(x, 30))
	province.refresh_fairways()
	var bollard := sim.data.get_building(&"bollard")
	assert_str(String(province.placement_error(bollard, Vector2i(12, 26)))).is_equal("needs_stone_quay")
	assert_str(String(province.placement_error(bollard, Vector2i(18, 31)))).is_equal("needs_stone_quay")
	# No port warehouse needed (owner's decision 2026-11-09).
	assert_str(String(province.placement_error(bollard, Vector2i(12, 31)))).is_empty()
	# People walk along the quay past it.
	var placed := SimFixture.place(sim, &"bollard", Vector2i(12, 31))
	assert_bool(province.nav.is_walkable(placed.origin)).is_true()
	assert_bool(province.nav.find_path(Vector2i(10, 31), Vector2i(14, 31)).is_empty()).is_false()
	assert_vector(placed.berth_tile()).is_equal(Vector2i(12, 32))


## Nobody carries a bollard's cargo without dockers; the dockers of a hut nearby unload it
## into the port warehouse (there is no port at all).
func test_dockers_of_a_hut_unload_a_ship_at_a_bollard_into_the_port_warehouse() -> void:
	var setup := _harbour_sim()
	var sim: Simulation = setup["sim"]
	var warehouse: BuildingState = setup["warehouse"]
	var bollard := SimFixture.place(sim, &"bollard", Vector2i(16, 31))
	assert_int(Harbour.yard_id(sim.province, bollard)).is_equal(warehouse.id)
	var ship := _cog_at(sim, bollard, 6)
	sim.province.jobs.add(&"wood", 6, ship.id, Harbour.yard_id(sim.province, bollard))
	# A porter does not take a ship's cargo.
	SimFixture.spawn(sim, JobBoard.PORTER_KIND, Vector2i(14, 26))
	SimFixture.run_until(sim, func() -> bool: return false, 20)
	assert_int(warehouse.stock.total(&"wood")).is_equal(0)
	_docker_hut(sim, Vector2i(18, 27))
	assert_bool(SimFixture.run_until(sim, func() -> bool: return warehouse.stock.total(&"wood") == 6, 240)).is_true()
	assert_int(ship.hold.total(&"wood")).is_equal(0)


## Dockers of a hut load a ship at a bollard from the port warehouse.
func test_dockers_load_a_ship_at_a_bollard_from_the_port_warehouse() -> void:
	var setup := _harbour_sim()
	var sim: Simulation = setup["sim"]
	var warehouse: BuildingState = setup["warehouse"]
	var bollard := SimFixture.place(sim, &"bollard", Vector2i(16, 31))
	warehouse.stock.add(&"planks", 4)
	var ship := _cog_at(sim, bollard, 0)
	sim.province.jobs.add(&"planks", 4, warehouse.id, ship.id)
	_docker_hut(sim, Vector2i(18, 27))
	assert_bool(SimFixture.run_until(sim, func() -> bool: return ship.hold.total(&"planks") == 4, 240)).is_true()


## Goods on a port's quay yard go to a port warehouse; with no porters, the dockers of a hut
## nearby carry them (the port has no dockers of its own here).
func test_dockers_of_a_hut_clear_a_quay_yard() -> void:
	var setup := _harbour_sim()
	var sim: Simulation = setup["sim"]
	var warehouse: BuildingState = setup["warehouse"]
	var port := SimFixture.place(sim, &"port", Vector2i(22, 28))
	port.stock.add(&"stone", 3)
	_docker_hut(sim, Vector2i(18, 27))
	assert_bool(SimFixture.run_until(sim, func() -> bool: return warehouse.stock.total(&"stone") == 3, 240)).is_true()


## Port warehouses have no staff; porters of an older game go home.
func test_port_warehouses_have_no_staff_and_old_porters_go_home() -> void:
	var setup := _harbour_sim()
	var sim: Simulation = setup["sim"]
	for id: StringName in [&"port_store", &"port_warehouse_small", &"port_warehouse"]:
		var def := sim.data.get_building(id)
		assert_int(def.worker_count()).is_equal(0)
		assert_bool(def.is_port_storage()).is_true()
	assert_int(sim.data.get_building(&"port_store").storage_slots).is_less(
			sim.data.get_building(&"port_warehouse_small").storage_slots)
	assert_int(sim.data.get_building(&"port_warehouse_small").storage_slots).is_less(
			sim.data.get_building(&"port_warehouse").storage_slots)
	var big := SimFixture.place(sim, &"port_warehouse", Vector2i(30, 26))
	var porter := SimFixture.spawn(sim, JobBoard.PORTER_KIND, big.door_front_tile())
	porter.workplace_id = big.id
	big.workers.append(porter.id)
	SimFixture.run_until(sim, func() -> bool: return false, 3)
	assert_bool(big.workers.is_empty()).is_true()
	assert_bool(sim.province.agents.has_agent(porter.id)).is_false()
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(24)


## A house of dockers and a port warehouse may stand 2 rows on piles over the sea; a hut only
## one; more asks for a quay under it.
func test_harbour_buildings_stand_up_to_two_rows_on_piles() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	var province := sim.province
	var house := sim.data.get_building(&"docker_house")
	assert_str(String(province.placement_error(house, Vector2i(20, 29)))).is_empty()
	assert_array(province.stilt_tiles(house, Vector2i(20, 29))).has_size(6)
	assert_str(String(province.placement_error(house, Vector2i(20, 30)))).is_equal("needs_quay")
	var warehouse := sim.data.get_building(&"port_warehouse")
	assert_str(String(province.placement_error(warehouse, Vector2i(26, 29)))).is_empty()
	var hut := sim.data.get_building(&"docker_hut")
	assert_str(String(province.placement_error(hut, Vector2i(14, 29)))).is_empty()
	assert_str(String(province.placement_error(hut, Vector2i(14, 30)))).is_equal("needs_quay")
	# Two doors: one to the land, one to the water side.
	assert_int(house.door_orientations(0).size()).is_equal(2)


## Without a port warehouse nearby, a ship at a bollard is unloaded into an ordinary storage
## and loaded from one, by the dockers of a hut.
func test_bollard_without_port_warehouse_uses_the_storages() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	var province := sim.province
	for x: int in range(10, 22):
		for y: int in range(30, 32):
			province.grid.set_quay(Vector2i(x, y), TileGrid.STONE_QUAY)
			province.refresh_tile(Vector2i(x, y))
	province.refresh_fairways()
	var stockpile := SimFixture.place(sim, &"stockpile", Vector2i(14, 22))
	stockpile.stock.add(&"planks", 3)
	var bollard := SimFixture.place(sim, &"bollard", Vector2i(16, 31))
	assert_int(Harbour.yard_id(province, bollard)).is_equal(0)
	_docker_hut(sim, Vector2i(18, 27))
	var ship := _cog_at(sim, bollard, 4)
	province.jobs.add(&"wood", 4, ship.id, 0)
	province.jobs.add(&"planks", 3, 0, ship.id)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return stockpile.stock.total(&"wood") == 4 and ship.hold.total(&"planks") == 3, 300)).is_true()


## The dockers' house on piles is drawn as stone quay, joining the stone quay beside it
## (owner's request 2026-11-09).
func test_dockers_house_strip_is_stone_quay() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	var province := sim.province
	for y: int in range(30, 32):
		province.grid.set_quay(Vector2i(19, y), TileGrid.STONE_QUAY)
		province.refresh_tile(Vector2i(19, y))
	province.refresh_fairways()
	SimFixture.place(sim, &"docker_house", Vector2i(20, 29))
	var hut := SimFixture.place(sim, &"docker_hut", Vector2i(26, 29))
	var tiles := QuayLayer.quay_tiles(province)
	for x: int in range(19, 23):
		assert_int(tiles.get(Vector2i(x, 30), 0)).is_equal(TileGrid.STONE_QUAY)
		assert_int(tiles.get(Vector2i(x, 31), 0)).is_equal(TileGrid.STONE_QUAY)
	# The hut keeps its timber deck on piles.
	assert_int(tiles.get(hut.origin + Vector2i(0, 1), 0)).is_equal(TileGrid.PIER)
