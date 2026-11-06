extends GdUnitTestSuite
## M6 part 3 DoD: a neutral settlement is a small ready town (30-40 buildings, 60-80 people)
## asking for gold and goods within a time limit. Gold is paid from the world map, goods come
## by trade route; when all is there in time it joins the player with its people and
## buildings. When the time runs out, a new demand 25% dearer comes 10 minutes later.


func _registry() -> DataRegistry:
	return SimFixture.registry()


func _residents(province: ProvinceSim) -> int:
	var sum := 0
	for b: BuildingState in province.buildings.all():
		if b.house != null:
			sum += b.house.residents
	return sum


func test_new_world_has_two_neutral_towns_that_wait() -> void:
	var problems := PackedStringArray()
	var sim := Simulation.from_world(_registry(), _registry().get_world(&"kingdom"), 1, problems)
	for id: StringName in [&"iron_wold", &"horse_haven"]:
		var pid := sim.world.id_of(id)
		assert_str(String(sim.world.owner_of(pid))).is_equal("neutral")
		var town := sim.province_state(pid)
		assert_object(town).is_not_null()
		var buildings := town.buildings.count()
		var residents := _residents(town)
		print("%s: %d buildings, %d residents, problems %s" % [id, buildings, residents, problems])
		assert_int(buildings).is_between(30, 45)
		assert_int(residents).is_between(60, 90)
		var s := sim.world.settlements[pid] as NeutralSettlement
		assert_int(s.gold).is_equal(300)
		assert_int(int(s.goods.get(&"bread", 0))).is_greater(0)
	# A neutral town does not run: nothing changes in it while it waits.
	var wold := sim.province_state(sim.world.id_of(&"iron_wold"))
	var bread := wold.kingdom_stock(&"bread")
	sim.run_ticks(SimFixture.ticks(60))
	assert_int(wold.kingdom_stock(&"bread")).is_equal(bread)
	assert_str(String(sim.execute(EnterProvinceCommand.new(sim.world.id_of(&"iron_wold"))))).is_not_empty()


## Landing Bay (48x48, a stable) buys Horse Haven: gold paid, bread and planks by wagon.
func test_buying_a_settlement_with_gold_and_a_wagon_route() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	sim.world = WorldSim.from_def(_registry().get_world(&"kingdom"), _registry())
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	var village := SimFixture.village(sim, 40, 80)
	(village["stock"] as BuildingState).stock.add(&"planks", 40)
	var stable := SimFixture.place(sim, &"stable", Vector2i(20, 10))
	for i: int in 2:
		var carter := SimFixture.spawn(sim, Carriers.CARTER_KIND, stable.entrance_tile())
		sim.execute(AssignWorkerCommand.new(carter.id, stable.id))
	for i: int in 4:
		SimFixture.spawn(sim, JobBoard.PORTER_KIND, Vector2i(12, 6))
	sim.province.entry_tile = Vector2i(47, 20)
	sim.treasury.gold = 1000
	var haven := sim.world.id_of(&"horse_haven")
	sim.run_ticks(SimFixture.ticks(11))   # the towns are set up within ten seconds
	var s := sim.world.settlements.get(haven) as NeutralSettlement
	assert_object(s).is_not_null()
	var town := sim.province_state(haven)
	var buildings := town.buildings.count()
	var residents := _residents(town)
	assert_str(String(sim.execute(PaySettlementCommand.new(haven)))).is_empty()
	assert_int(sim.treasury.gold).is_less_equal(1000 - 300)
	assert_str(String(sim.execute(PaySettlementCommand.new(haven)))).is_equal("already_paid")
	# Both wagons of the stable: one route each.
	for good: StringName in s.goods:
		var lines: Array[Dictionary] = [TradeRoute.line(good, TradeRoute.WAGON_LOAD, 0)]
		assert_str(String(sim.execute(CreateTradeRouteCommand.new(WorldSim.FIRST_ID, haven, false,
				stable.id, lines)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.world.owner_of(haven) == ProvinceDef.OWNER_PLAYER, 20 * 60)).is_true()
	assert_bool(sim.world.settlements.has(haven)).is_false()
	assert_int(town.buildings.count()).is_equal(buildings)
	assert_int(_residents(town)).is_equal(residents)
	# Now it is the player's: it runs and can be entered.
	assert_str(String(sim.execute(EnterProvinceCommand.new(haven)))).is_empty()
	sim.run_ticks(SimFixture.ticks(30))
	assert_int(sim.province.agents.count()).is_greater(20)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_demand_not_met_in_time_comes_back_dearer() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	sim.world = WorldSim.from_def(_registry().get_world(&"kingdom"), _registry())
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	sim.treasury.gold = 100
	var wold := sim.world.id_of(&"iron_wold")
	sim.run_ticks(SimFixture.ticks(11))
	var s := sim.world.settlements[wold] as NeutralSettlement
	assert_str(String(sim.execute(PaySettlementCommand.new(wold)))).is_empty()
	assert_int(s.gold_paid).is_equal(100)
	assert_int(sim.treasury.gold).is_equal(0)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return s.state == NeutralSettlement.State.RESTING, 21 * 60)).is_true()
	assert_str(String(sim.execute(PaySettlementCommand.new(wold)))).is_equal("no_demand")
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return s.state == NeutralSettlement.State.ASKING, 11 * 60)).is_true()
	assert_int(s.gold).is_equal(375)
	assert_int(s.gold_paid).is_equal(0)
	assert_int(int(s.goods[&"bread"])).is_equal(50)
	assert_str(String(sim.world.owner_of(wold))).is_equal("neutral")
	var state := sim.to_dict()
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", false, true)), _registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(state))
