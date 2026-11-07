extends GdUnitTestSuite
## N1 part 2: a cargo crane on the quay by a berth lifts 3 units at a time between the quay
## yard and the moored ship, beside the dockers (about twice what two dockers carry); a port
## warehouse is a storage that stands on the quay.


## 48x48 like test_n1_quays: land above row 30, shallow sea rows 30-32, deep from row 33. A
## port at (20, 28) and a pier block (10..13, 30..31) with a mooring at (10, 30): its berth is
## (11, 32). No porters: only the dockers and the crane carry.
func _harbour_sim() -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	sim.treasury.gold = 500
	var province := sim.province
	for y: int in range(30, 32):
		for x: int in range(10, 14):
			province.grid.set_quay(Vector2i(x, y), TileGrid.PIER)
			province.refresh_tile(Vector2i(x, y))
	province.refresh_fairways()
	var port := SimFixture.place(sim, &"port", Vector2i(20, 28))
	var mooring := SimFixture.place(sim, &"mooring", Vector2i(10, 30))
	return {"sim": sim, "port": port, "mooring": mooring}


func _dockers(sim: Simulation, port: BuildingState, at: Vector2i) -> void:
	for i: int in 2:
		var docker := SimFixture.spawn(sim, Harbour.DOCKER_KIND, at)
		assert_str(String(sim.execute(AssignWorkerCommand.new(docker.id, port.id)))).is_empty()


## A crane at (12, 30) by the mooring's berth; returns its operator.
func _crane(sim: Simulation) -> Agent:
	var crane := SimFixture.place(sim, &"crane", Vector2i(12, 30))
	var operator := SimFixture.spawn(sim, Cranes.OPERATOR_KIND, crane.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(operator.id, crane.id)))).is_empty()
	return operator


## A cog moored at the mooring with [param wood] wood on the quay yard to load.
func _cog_to_load(sim: Simulation, mooring: BuildingState, wood: int) -> ShipUnit:
	var province := sim.province
	var ship := ShipUnit.new(province.ids.take(), sim.data.get_ship(&"foreign_cog"),
			IsoMath.tile_center(mooring.berth_tile()), sim.data)
	province.ships[ship.id] = ship
	Harbour.moor(ship, mooring)
	mooring.stock.add(&"wood", wood)
	province.jobs.add(&"wood", wood, mooring.id, ship.id)
	return ship


## Seconds until [param wood] wood is aboard, at most [param limit].
func _load_time(sim: Simulation, ship: ShipUnit, wood: int, limit: float) -> float:
	var start := sim.province.tick
	var done := SimFixture.run_until(sim, func() -> bool: return ship.hold.total(&"wood") >= wood, limit)
	assert_bool(done).is_true()
	return float(sim.province.tick - start) / SimClock.TICKS_PER_SECOND


func test_crane_stands_on_the_quay_by_a_berth() -> void:
	var setup := _harbour_sim()
	var sim: Simulation = setup["sim"]
	var province := sim.province
	var crane := sim.data.get_building(&"crane")
	assert_str(String(province.placement_error(crane, Vector2i(12, 30)))).is_empty()
	# On land: only on a quay.
	assert_str(String(province.placement_error(crane, Vector2i(12, 26)))).is_equal("needs_quay")
	# A quay with no berth within 2 tiles.
	for y: int in range(30, 32):
		for x: int in range(30, 32):
			province.grid.set_quay(Vector2i(x, y), TileGrid.PIER)
			province.refresh_tile(Vector2i(x, y))
	assert_str(String(province.placement_error(crane, Vector2i(30, 30)))).is_equal("no_berth_nearby")
	var warehouse := sim.data.get_building(&"port_warehouse")
	assert_str(String(province.placement_error(warehouse, Vector2i(30, 26)))).is_equal("needs_quay")


## Two dockers alone, the crane alone, both together: the crane lifts 3 at a time and moves
## about twice what the dockers carry; together they load the fastest.
func test_crane_loads_about_twice_as_fast_as_two_dockers() -> void:
	var a := _harbour_sim()
	var sim_a: Simulation = a["sim"]
	_dockers(sim_a, a["port"], (a["mooring"] as BuildingState).entrance_tile())
	var dockers := _load_time(sim_a, _cog_to_load(sim_a, a["mooring"], 24), 24, 600)

	var b := _harbour_sim()
	var sim_b: Simulation = b["sim"]
	_crane(sim_b)
	var ship_b := _cog_to_load(sim_b, b["mooring"], 24)
	var lifted: Array[int] = []
	var start := sim_b.province.tick
	for i: int in SimFixture.ticks(600):
		sim_b.step()
		for event: Dictionary in sim_b.events.drain():
			if event["type"] == &"good_stored" and int(event["storage"]) == ship_b.id:
				lifted.append(int(event["amount"]))
		if ship_b.hold.total(&"wood") >= 24:
			break
	assert_int(ship_b.hold.total(&"wood")).is_equal(24)
	var crane := float(sim_b.province.tick - start) / SimClock.TICKS_PER_SECOND

	var c := _harbour_sim()
	var sim_c: Simulation = c["sim"]
	_dockers(sim_c, c["port"], (c["mooring"] as BuildingState).entrance_tile())
	_crane(sim_c)
	var both := _load_time(sim_c, _cog_to_load(sim_c, c["mooring"], 24), 24, 600)

	print("load 24 wood: dockers %.1f s, crane %.1f s, both %.1f s" % [dockers, crane, both])
	# 3 at a time, less only where a stack on the yard runs out.
	assert_int(lifted.max()).is_equal(Cranes.CRANE_LOAD)
	assert_int(lifted.count(Cranes.CRANE_LOAD)).is_greater_equal(6)
	assert_float(dockers / crane).is_between(1.7, 2.6)
	assert_float(both).is_less(crane)
	assert_int(sim_c.province.jobs.count()).is_equal(0)


## A save in the middle of a lift resumes there: the load lands aboard.
func test_lift_survives_save_and_load() -> void:
	var setup := _harbour_sim()
	var sim: Simulation = setup["sim"]
	var operator := _crane(sim)
	var ship := _cog_to_load(sim, setup["mooring"], 3)
	var midway := SimFixture.run_until(sim, func() -> bool:
		return Cranes.lift_progress(operator) > 0.2, 60)
	assert_bool(midway).is_true()
	var copy := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())), sim.data)
	var copy_ship := copy.province.ships.get(ship.id) as ShipUnit
	assert_bool(SimFixture.run_until(copy, func() -> bool: return copy_ship.hold.total(&"wood") == 3, 30)).is_true()
	assert_int(copy.province.jobs.count()).is_equal(0)
	assert_int(copy.province.reservation_count()).is_equal(0)


## The ship casts off in the middle of a lift: nothing is lost, the wood stays on the quay.
func test_ship_leaving_mid_lift_loses_nothing() -> void:
	var setup := _harbour_sim()
	var sim: Simulation = setup["sim"]
	var mooring: BuildingState = setup["mooring"]
	var operator := _crane(sim)
	var ship := _cog_to_load(sim, mooring, 3)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return Cranes.lift_progress(operator) > 0.2, 60)).is_true()
	# Cast off as the sea merchant does: whoever is carrying for the ship stops.
	for agent: Agent in sim.province.agents.all():
		if agent.task != null and (int(agent.task.bb.get("_src", 0)) == ship.id \
				or int(agent.task.bb.get("_dst", 0)) == ship.id):
			TaskRunner.fail(sim.province, agent)
	sim.province.jobs.cancel_for_entity(ship.id)
	ship.berth_id = 0
	ship.dock_id = 0
	sim.run_ticks(SimFixture.ticks(10))
	assert_int(ship.hold.total(&"wood")).is_equal(0)
	assert_int(mooring.stock.total(&"wood")).is_equal(3)
	assert_int(sim.province.reservation_count()).is_equal(0)
	assert_float(Cranes.lift_progress(operator)).is_equal(-1.0)


## The port warehouse is an ordinary storage on the quay: its porters bring goods to it.
func test_port_warehouse_is_a_storage_on_the_quay() -> void:
	var setup := _harbour_sim()
	var sim: Simulation = setup["sim"]
	var province := sim.province
	for y: int in range(30, 33):
		for x: int in range(5, 8):
			province.grid.set_quay(Vector2i(x, y), TileGrid.PIER)
			province.refresh_tile(Vector2i(x, y))
	province.refresh_fairways()
	var warehouse := SimFixture.place(sim, &"port_warehouse", Vector2i(5, 30))
	assert_int(warehouse.stock.slot_count()).is_equal(8)
	var porter := SimFixture.spawn(sim, JobBoard.PORTER_KIND, warehouse.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(porter.id, warehouse.id)))).is_empty()
	# Wood on the ground by the shore goes into the warehouse.
	province.drop_goods(Vector2i(4, 27), &"wood", 4)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return warehouse.stock.total(&"wood") == 4, 120)).is_true()


## The v16 fixture (tools/build_crane_fixture.gd): loads unchanged in the middle of a lift and
## the lift lands aboard.
func test_v16_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v16_crane.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(16)
	var state := SaveMigrations.migrate(document["state"], 16)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var province := sim.province
	var operator: Agent = null
	for agent: Agent in province.agents.all():
		if agent.kind == Cranes.OPERATOR_KIND:
			operator = agent
	assert_float(Cranes.lift_progress(operator)).is_greater(0.0)
	# Both ends of the lift are held, by the operator's task.
	assert_array(Array(province.dangling_holds())).is_empty()
	var load := int(operator.task.bb["_load"])
	var ship_id := int(operator.task.bb["_dst"])
	var ship := province.ships.get(ship_id) as ShipUnit
	var before := ship.hold.total(&"wood")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return ship.hold.total(&"wood") >= before + load, 10)).is_true()
	assert_array(Array(province.dangling_holds())).is_empty()


## A v15 game migrates to v16 unchanged.
func test_v15_save_migrates_to_v16_unchanged() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v15_quays.json"))
	var state := SaveMigrations.migrate(document["state"], 15)
	assert_str(SimCodec.canonical(state)).is_equal(SimCodec.canonical(document["state"]))
