extends GdUnitTestSuite
## M5 part 3 DoD: the player's cog is built at the shipyard in 4 stages (frame, planking,
## mast with sail, launch), finds its home port and waits at anchor; a trade voyage loads the
## plan over the gangway, sails over the horizon, sells at the base price + 25% and comes back
## with the gold and the order bought from the sea merchant's offer. Saves taken while the
## cog is built and while it is away play on alike.


## 48x48: land above row 30, shallow sea rows 30-32, deep sea from row 33. A village, a
## storage, a port at (20, 28) and a shipyard at (30, 28).
func _scene(seed_value: int = 1) -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48), seed_value)
	SimFixture.coast(sim, 30, 33)
	SimFixture.village(sim, 10, 40)
	for i: int in 4:
		SimFixture.house(sim, Vector2i(2 + 3 * i, 12))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(14, 22))
	stock.stock.add(&"wood", 60)
	stock.stock.add(&"planks", 20)
	stock.stock.add(&"tar", 6)
	stock.stock.add(&"cloth", 4)
	sim.treasury.gold = 500
	var port := SimFixture.place(sim, &"port", Vector2i(20, 28))
	var shipyard := SimFixture.place(sim, &"shipyard", Vector2i(30, 28))
	# Workers without a home: houses short of goods cannot take them away mid-test.
	for kind: StringName in [Harbour.DOCKER_KIND, Harbour.DOCKER_KIND]:
		var docker := SimFixture.spawn(sim, kind, port.entrance_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(docker.id, port.id)))).is_empty()
	var wright := SimFixture.spawn(sim, &"shipwright", shipyard.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(wright.id, shipyard.id)))).is_empty()
	for i: int in 3:
		SimFixture.spawn(sim, JobBoard.PORTER_KIND, Vector2i(16, 20))
	# Nobody else comes to the berth during the test.
	sim.province.sea_merchant.next_visit = 1 << 30
	return {"sim": sim, "stock": stock, "port": port, "shipyard": shipyard}


## A finished player's cog at anchor near the port.
func _cog_at_anchor(sim: Simulation, shipyard: BuildingState) -> ShipUnit:
	var cog := Ships.launch(sim.province, sim.data.get_ship(&"cog"), shipyard)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.home_id != 0 and cog.tile() == cog.voyage.anchor \
				and cog.path_state != ShipUnit.PathState.MOVING, 120)).is_true()
	return cog


func test_cog_is_built_in_four_stages_and_waits_at_anchor() -> void:
	var scene := _scene()
	var sim: Simulation = scene["sim"]
	var shipyard: BuildingState = scene["shipyard"]
	var port: BuildingState = scene["port"]
	assert_str(String(sim.execute(OrderShipCommand.new(shipyard.id, &"cog")))).is_empty()
	var stages: Array[int] = []
	var costs: Array = []
	var launched := 0
	for i: int in SimFixture.ticks(900):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"ship_stage_started":
				stages.append(int(e["stage"]))
				var build := sim.province.ship_builds[int(e["build"])] as ShipBuild
				costs.append(build.current_cost())
			if e["type"] == &"ship_launched":
				launched = int(e["ship"])
		if launched != 0:
			break
	print("cog stages: ", stages, " costs ", costs)
	assert_array(stages).is_equal([0, 1, 2, 3])
	assert_dict(costs[0]).is_equal({&"planks": 8})
	assert_dict(costs[2]).is_equal({&"cloth": 4, &"planks": 2})
	assert_int(launched).is_not_zero()
	var cog := sim.province.ships[launched] as ShipUnit
	assert_object(cog.voyage).is_not_null()
	# Review fix 2026-11-07: it lies bow down the slipway, as it slid into the water.
	assert_int(cog.facing).is_equal(Ships.slipway_dir(shipyard))
	# It finds the port, leaves the shipyard and waits at anchor in deep water, the berth free.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.home_id == port.id and cog.tile() == cog.voyage.anchor, 120)).is_true()
	assert_int(sim.province.sail_depth(cog.tile())).is_equal(2)
	assert_object(Harbour.berth_holder(sim.province, port)).is_null()
	assert_int(cog.dock_id).is_equal(0)


func test_voyage_sells_over_the_horizon_and_brings_the_order() -> void:
	var scene := _scene()
	var sim: Simulation = scene["sim"]
	var port: BuildingState = scene["port"]
	var cog := _cog_at_anchor(sim, scene["shipyard"])
	assert_str(String(sim.execute(SetVoyagePlanCommand.new(cog.id, &"wood", 30)))).is_empty()
	assert_str(String(sim.execute(SetVoyagePlanCommand.new(cog.id, &"tar", 10, true)))).is_empty()
	assert_str(String(sim.execute(SetVoyagePlanCommand.new(cog.id, &"wood", 10, true)))).is_equal("not_offered")
	assert_str(String(sim.execute(SetVoyagePlanCommand.new(cog.id, &"bread", 50)))).is_equal("hold_full")
	var wood := sim.province.goods_total(&"wood")
	var tar := sim.province.goods_total(&"tar")
	assert_str(String(sim.execute(StartVoyageCommand.new(cog.id)))).is_empty()
	var seen := {"gangway": false, "loaded": 0, "away": false, "left_map": false}
	var gold_before_away := 0
	var province := sim.province
	var quay: Array[Vector2i] = port.def.water_tiles_at(port.origin, port.orientation)
	var times := {}
	for i: int in SimFixture.ticks(1500):
		if not times.has(cog.voyage.state):
			times[cog.voyage.state] = i / SimClock.TICKS_PER_SECOND
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_stored" and int(e["storage"]) == cog.id:
				seen["loaded"] = int(seen["loaded"]) + int(e["amount"])
			if e["type"] == &"voyage_departed":
				gold_before_away = sim.treasury.gold
		for agent: Agent in province.agents.all():
			if agent.kind == Harbour.DOCKER_KIND and quay.has(agent.tile()) and agent.activity == &"walk":
				seen["gangway"] = true
		if cog.is_away():
			seen["away"] = true
			var at := cog.tile()
			seen["left_map"] = at.x == 0 or at.y == 0 or at.x == 47 or at.y == 47
		if seen["away"] and cog.voyage.state == Voyage.State.IDLE:
			break
	var v := cog.voyage
	print("voyage: ", seen, " state seconds ", times, " earned ", v.last_earned, " spent ", v.last_spent)
	assert_bool(seen["gangway"]).is_true()
	assert_int(int(seen["loaded"])).is_equal(30)
	assert_bool(seen["away"]).is_true()
	assert_bool(seen["left_map"]).is_true()
	assert_int(v.state).is_equal(Voyage.State.IDLE)
	assert_int(v.last_sold).is_equal(30)
	assert_int(v.last_earned).is_equal(30 * Voyage.sale_price(province, &"wood"))
	assert_int(v.last_spent).is_equal(10 * SeaMerchant.sell_price(province, &"tar"))
	assert_int(v.last_bought).is_equal(10)
	# Wood is gone, tar arrived and porters take it to a storage; the cog is back at anchor.
	sim.run_ticks(SimFixture.ticks(90))
	assert_int(province.goods_total(&"wood")).is_equal(wood - 30)
	assert_int(province.goods_total(&"tar")).is_equal(tar + 10)
	assert_int(port.stock.total(&"tar")).is_equal(0)
	assert_bool(cog.hold.is_empty()).is_true()
	assert_object(Harbour.berth_holder(province, port)).is_null()
	assert_array(Array(province.dangling_holds())).is_empty()


func test_cast_off_now_leaves_with_what_is_aboard() -> void:
	var scene := _scene()
	var sim: Simulation = scene["sim"]
	var cog := _cog_at_anchor(sim, scene["shipyard"])
	assert_str(String(sim.execute(StartVoyageCommand.new(cog.id, true)))).is_equal("not_loading")
	assert_str(String(sim.execute(SetVoyagePlanCommand.new(cog.id, &"wood", 40)))).is_empty()
	assert_str(String(sim.execute(StartVoyageCommand.new(cog.id)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool: return cog.hold.total(&"wood") >= 3, 300)).is_true()
	assert_str(String(sim.execute(StartVoyageCommand.new(cog.id, true)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.voyage.state == Voyage.State.OUTBOUND, 60)).is_true()
	assert_int(cog.hold.total(&"wood")).is_less(40)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func _reload(sim: Simulation) -> Simulation:
	var state := sim.to_dict()
	return Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", true, true)), SimFixture.registry())


func _same_after(sim: Simulation, seconds: float) -> void:
	var copy := _reload(sim)
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		copy.step()
		sim.events.drain()
		copy.events.drain()
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	assert_array(Array(copy.province.dangling_holds())).is_empty()


func test_save_while_the_cog_is_built_continues_alike() -> void:
	var scene := _scene(3)
	var sim: Simulation = scene["sim"]
	assert_str(String(sim.execute(OrderShipCommand.new((scene["shipyard"] as BuildingState).id, &"cog")))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		for build: ShipBuild in sim.province.ship_builds.values():
			if build.stage == 1 and build.stage_started:
				return true
		return false, 600)).is_true()
	_same_after(sim, 120)


func test_save_while_the_cog_is_away_continues_alike() -> void:
	var scene := _scene(4)
	var sim: Simulation = scene["sim"]
	var cog := _cog_at_anchor(sim, scene["shipyard"])
	assert_str(String(sim.execute(SetVoyagePlanCommand.new(cog.id, &"wood", 10)))).is_empty()
	assert_str(String(sim.execute(SetVoyagePlanCommand.new(cog.id, &"planks", 5, true)))).is_empty()
	assert_str(String(sim.execute(StartVoyageCommand.new(cog.id)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool: return cog.is_away(), 600)).is_true()
	var copy := _reload(sim)
	var copied := copy.province.ships[cog.id] as ShipUnit
	assert_int(copied.voyage.state).is_equal(Voyage.State.AWAY)
	assert_dict(copied.hold.totals()).is_equal({&"planks": 5})
	_same_after(sim, Voyage.AWAY_TIME + 120)
