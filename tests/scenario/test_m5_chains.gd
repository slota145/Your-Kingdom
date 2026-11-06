extends GdUnitTestSuite
## M5 part 1 DoD: the tar kiln makes tar from wood; the shipyard builds a fishing boat from
## planks and tar brought by porters; the fishing wharf's fisherman fetches the boat, sails to
## a shoal, fishes with a net, sails back and carries the fish to a storage, catching clearly
## more than an angler; shoals grow back. Saves taken mid-trip and mid-build play on alike.


## 48x48: land above row 30, shallow sea rows 30-32, deep sea from row 33. A village (town
## hall with porters and a builder, a storage) in the north, shoals out at sea.
func _harbour_sim(seed_value: int = 1) -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48), seed_value)
	SimFixture.coast(sim, 30, 33)
	var scene := SimFixture.village(sim, 60, 60)
	var stock: BuildingState = scene["stock"]
	stock.stock.add(&"planks", 20)
	stock.stock.add(&"tar", 4)
	for i: int in 2:
		SimFixture.house(sim, Vector2i(2 + 3 * i, 12))
	var shoal := sim.data.get_resource_node(&"fish_shoal")
	for tile: Vector2i in [Vector2i(30, 38), Vector2i(20, 40), Vector2i(40, 36)]:
		sim.province.resources.place(tile, shoal)
		sim.province.refresh_tile(tile)
	return {"sim": sim, "stock": stock}


func _worker(sim: Simulation, building: BuildingState, kind: StringName) -> Agent:
	var agent := SimFixture.spawn(sim, kind, building.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(agent.id, building.id)))).is_empty()
	return agent


func test_tar_kiln_makes_tar_from_wood() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	stock.stock.add(&"wood", 10)
	var kiln := SimFixture.place(sim, &"tar_kiln", Vector2i(10, 4))
	_worker(sim, kiln, &"tar_burner")
	var burned := {"smoke": false}
	for i: int in SimFixture.ticks(130.0):
		sim.step()
		sim.events.drain()
		for agent: Agent in sim.province.agents.all():
			if agent.activity == &"tend_fire":
				burned["smoke"] = true
	assert_bool(burned["smoke"]).is_true()
	assert_int(stock.stock.total(&"tar")).is_greater_equal(2)
	# 2 wood for each barrel.
	assert_int(stock.stock.total(&"wood") + 2 * stock.stock.total(&"tar")).is_less_equal(10)


func test_shipyard_builds_a_boat_with_materials_from_porters() -> void:
	var scene := _harbour_sim()
	var sim: Simulation = scene["sim"]
	var stock: BuildingState = scene["stock"]
	var shipyard := SimFixture.place(sim, &"shipyard", Vector2i(20, 28))
	_worker(sim, shipyard, &"shipwright")
	assert_str(String(sim.execute(OrderShipCommand.new(shipyard.id, &"cog")))).is_equal("ship_not_built_here")
	assert_str(String(sim.execute(OrderShipCommand.new(shipyard.id, &"fishing_boat")))).is_empty()
	var province := sim.province
	var stages := {}
	var built := false
	for i: int in SimFixture.ticks(400.0):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"ship_stage_started":
				stages[e["stage"]] = true
			if e["type"] == &"ship_launched":
				built = true
		if built:
			break
	assert_bool(built).is_true()
	assert_dict(stages).is_equal({0: true, 1: true})
	assert_int(province.ships.size()).is_equal(1)
	assert_array(shipyard.ship_orders).is_empty()
	assert_int(province.ship_builds.size()).is_equal(0)
	var ship: ShipUnit = province.ships.values()[0]
	assert_vector(ship.tile()).is_equal(shipyard.berth_tile())
	assert_int(ship.dock_id).is_equal(shipyard.id)
	# 6 planks and 2 tar went into the boat.
	assert_int(stock.stock.total(&"planks")).is_less_equal(14)
	assert_int(stock.stock.total(&"tar")).is_equal(2)
	assert_array(Array(province.dangling_holds())).is_empty()


func test_fisherman_fetches_the_boat_and_lands_fish() -> void:
	var scene := _harbour_sim()
	var sim: Simulation = scene["sim"]
	var stock: BuildingState = scene["stock"]
	var province := sim.province
	var shipyard := SimFixture.place(sim, &"shipyard", Vector2i(20, 28))
	var wharf := SimFixture.place(sim, &"fishing_wharf", Vector2i(32, 28))
	# The boat waits at the shipyard where it was launched.
	var boat := Ships.launch(province, sim.data.get_ship(&"fishing_boat"), shipyard)
	var fisher := _worker(sim, wharf, &"fisher")
	var seen := {}
	var landed := false
	for i: int in SimFixture.ticks(240.0):
		sim.step()
		sim.events.drain()
		seen[fisher.activity] = true
		if fisher.vehicle == Ships.ABOARD:
			seen["aboard"] = true
			assert_vector(fisher.pos).is_equal(boat.pos)
			assert_bool(province.boat_nav.is_walkable(boat.tile())).is_true()
		if stock.stock.total(&"fish") > 0:
			landed = true
			break
	assert_bool(landed).is_true()
	assert_int(boat.home_id).is_equal(wharf.id)
	assert_bool(seen.has("aboard")).is_true()
	for activity: StringName in [&"cast_net", &"wait_net", &"haul_net"]:
		assert_bool(seen.has(activity)).override_failure_message(String(activity)).is_true()
	assert_int(stock.stock.total(&"fish")).is_equal(6)
	assert_array(Array(province.dangling_holds())).is_empty()


## Fish in 10 minutes: a wharf with its boat against an angler on the same shore.
func _catch(building: StringName, worker: StringName) -> int:
	var scene := _harbour_sim()
	var sim: Simulation = scene["sim"]
	var place := SimFixture.place(sim, building, Vector2i(32, 28))
	if building == &"fishing_wharf":
		var boat := Ships.launch(sim.province, sim.data.get_ship(&"fishing_boat"), place)
		boat.home_id = place.id
	_worker(sim, place, worker)
	var caught := 0
	for i: int in SimFixture.ticks(600.0):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] in [&"good_gathered", &"good_produced"] and e["good"] == &"fish":
				caught += int(e["amount"])
	return caught


func test_wharf_catches_clearly_more_than_an_angler() -> void:
	var wharf := _catch(&"fishing_wharf", &"fisher")
	var angler := _catch(&"fishing_hut", &"angler")
	print("fish in 10 min: wharf %d, angler %d" % [wharf, angler])
	assert_int(angler).is_greater(0)
	assert_float(float(wharf) / angler).is_greater_equal(1.5)


func test_shoals_grow_back() -> void:
	var sim := SimFixture.make_sim(Vector2i(16, 16))
	SimFixture.coast(sim, 4, 8)
	var tile := Vector2i(5, 10)
	sim.province.resources.place(tile, sim.data.get_resource_node(&"fish_shoal"))
	sim.province.resources.take(tile)
	sim.province.resources.take(tile)
	sim.province.resources.take(tile)
	assert_bool(sim.province.resources.has_node(tile)).is_false()
	sim.run_ticks(SimFixture.ticks(61.0))
	assert_int(sim.province.resources.amount(tile)).is_between(3, 4)
	sim.run_ticks(SimFixture.ticks(400.0))
	assert_int(sim.province.resources.amount(tile)).is_equal(18)


func test_wharf_demolished_while_at_sea_loses_nothing() -> void:
	var scene := _harbour_sim()
	var sim: Simulation = scene["sim"]
	var province := sim.province
	var wharf := SimFixture.place(sim, &"fishing_wharf", Vector2i(32, 28))
	var boat := Ships.launch(province, sim.data.get_ship(&"fishing_boat"), wharf)
	boat.home_id = wharf.id
	var fisher := _worker(sim, wharf, &"fisher")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return fisher.is_carrying(), 200.0)).is_true()
	var fish := province.goods_total(&"fish")
	province.remove_building(wharf.id)
	assert_int(province.goods_total(&"fish")).is_equal(fish)
	assert_int(boat.home_id).is_equal(0)
	assert_int(boat.hold.total(&"fish")).is_equal(6)
	sim.run_ticks(SimFixture.ticks(30.0))
	assert_array(Array(province.dangling_holds())).is_empty()
	# A new wharf takes the boat over: it sails home on its own.
	var second := SimFixture.place(sim, &"fishing_wharf", Vector2i(10, 28))
	assert_bool(SimFixture.run_until(sim, func() -> bool: return boat.dock_id == second.id, 120.0)).is_true()


func _reload(sim: Simulation) -> Simulation:
	var text := JSON.stringify(sim.to_dict(), "", false, true)
	return Simulation.from_dict(JSON.parse_string(text), SimFixture.registry())


func test_save_mid_trip_and_mid_build_continues_alike() -> void:
	var scene := _harbour_sim(7)
	var sim: Simulation = scene["sim"]
	var shipyard := SimFixture.place(sim, &"shipyard", Vector2i(20, 28))
	var wharf := SimFixture.place(sim, &"fishing_wharf", Vector2i(32, 28))
	_worker(sim, shipyard, &"shipwright")
	var fisher := _worker(sim, wharf, &"fisher")
	sim.execute(OrderShipCommand.new(shipyard.id, &"fishing_boat"))
	sim.execute(OrderShipCommand.new(shipyard.id, &"fishing_boat"))
	# Run until the first boat is out fishing and the second one is on the slipway.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return fisher.vehicle == Ships.ABOARD and not sim.province.ship_builds.is_empty(), 600.0)).is_true()
	var first := SimCodec.canonical(sim.to_dict())
	var loaded := _reload(sim)
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(first)
	for chunk: int in 4:
		sim.run_ticks(300)
		loaded.run_ticks(300)
		assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	assert_array(Array(loaded.province.dangling_holds())).is_empty()


func test_materials_lost_on_the_way_are_asked_for_again() -> void:
	var scene := _harbour_sim()
	var sim: Simulation = scene["sim"]
	var province := sim.province
	var shipyard := SimFixture.place(sim, &"shipyard", Vector2i(20, 28))
	_worker(sim, shipyard, &"shipwright")
	sim.execute(OrderShipCommand.new(shipyard.id, &"fishing_boat"))
	var carrier := {"agent": null}
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		for agent: Agent in province.agents.all():
			if agent.is_carrying() and agent.task != null and province.ship_builds.has(int(agent.task.bb.get("to", 0))):
				carrier["agent"] = agent
				return true
		return false, 120.0)).is_true()
	# The porter loses his job on the way: his load goes on the ground.
	province.remove_agent(carrier["agent"])
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.ships.size() == 1, 400.0)).is_true()
	assert_array(Array(province.dangling_holds())).is_empty()
