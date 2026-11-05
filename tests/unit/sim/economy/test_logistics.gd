extends GdUnitTestSuite
## M4a logistics (ROADMAP M4 decisions): porters in stockpiles, a wood reserve that
## construction leaves for houses, work priorities, taxes and gold.


func _count(sim: Simulation, kind: StringName) -> int:
	var n := 0
	for agent: Agent in sim.province.agents.all():
		if agent.kind == kind:
			n += 1
	return n


func test_stockpile_employs_two_porters_after_the_town_hall() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim)
	var stock: BuildingState = village["stock"]
	# 8 residents = 4 workers: town hall 3, the stockpile gets the last one.
	sim.run_ticks(SimFixture.ticks(2))
	assert_int(stock.workers.size()).is_equal(1)
	SimFixture.house(sim, Vector2i(8, 8))
	sim.run_ticks(SimFixture.ticks(2))
	assert_int(stock.workers.size()).is_equal(2)
	assert_int(_count(sim, &"porter")).is_equal(4)


func test_production_is_staffed_before_stockpile_porters() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim)
	var mill := SimFixture.place(sim, &"mill", Vector2i(14, 4))
	sim.run_ticks(SimFixture.ticks(2))
	assert_int(mill.workers.size()).is_equal(1)
	assert_int((village["stock"] as BuildingState).workers.size()).is_equal(0)


func test_construction_leaves_the_wood_reserve() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim, 12, 20)
	var stock: BuildingState = village["stock"]
	assert_int(int(stock.reserves[&"wood"])).is_equal(5)
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"mill", Vector2i(14, 4))))).is_equal("")
	var mill := sim.province.buildings.get_building(sim.province.grid.occupant(Vector2i(14, 4)))
	sim.run_ticks(SimFixture.ticks(90))
	# The mill needs 8 wood: only 7 may leave the stockpile, so it is stuck in phase 2.
	assert_int(stock.stock.total(&"wood")).is_equal(5)
	assert_bool(mill.is_complete()).is_false()
	# Households still take firewood from the reserve.
	var pantry_wood := 0
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			b.supply.remove(&"wood", 3)
	sim.run_ticks(SimFixture.ticks(20))
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			pantry_wood += b.supply.total(&"wood")
	assert_int(pantry_wood).is_greater(0)
	assert_int(stock.stock.total(&"wood")).is_less(5)
	# The player lowers the reserve: the rest goes to the site.
	assert_str(String(sim.execute(SetReserveCommand.new(stock.id, &"wood", 0)))).is_equal("")
	var done := SimFixture.run_until(sim, func() -> bool: return mill.is_complete(), 180)
	assert_bool(done).is_true()
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_reserve_command_is_validated() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim)
	var stock: BuildingState = village["stock"]
	var hall: BuildingState = village["hall"]
	assert_str(String(sim.execute(SetReserveCommand.new(hall.id, &"wood", 3)))).is_equal("not_a_storage")
	assert_str(String(sim.execute(SetReserveCommand.new(stock.id, &"gold_bars", 3)))).is_equal("unknown_good")
	assert_str(String(sim.execute(SetReserveCommand.new(stock.id, &"wood", -1)))).is_equal("invalid_value")
	assert_str(String(sim.execute(SetReserveCommand.new(stock.id, &"wood", 12)))).is_equal("")
	assert_int(int(stock.reserves[&"wood"])).is_equal(12)


func test_high_priority_takes_a_worker_from_a_lower_one() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.village(sim)
	var bakery := SimFixture.place(sim, &"bakery", Vector2i(18, 4))
	var mill := SimFixture.place(sim, &"mill", Vector2i(14, 4))
	sim.run_ticks(SimFixture.ticks(2))
	# One worker left after the town hall: the older bakery gets it.
	assert_int(bakery.workers.size()).is_equal(1)
	assert_int(mill.workers.size()).is_equal(0)
	assert_str(String(sim.execute(SetPriorityCommand.new(mill.id, BuildingState.Priority.HIGH)))).is_equal("")
	sim.run_ticks(SimFixture.ticks(3))
	assert_int(mill.workers.size()).is_equal(1)
	assert_int(bakery.workers.size()).is_equal(0)
	# And it stays that way.
	sim.run_ticks(SimFixture.ticks(10))
	assert_int(mill.workers.size()).is_equal(1)
	assert_int(bakery.workers.size()).is_equal(0)


func test_low_priority_is_staffed_last() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.village(sim)
	var bakery := SimFixture.place(sim, &"bakery", Vector2i(18, 4))
	var mill := SimFixture.place(sim, &"mill", Vector2i(14, 4))
	sim.execute(SetPriorityCommand.new(bakery.id, BuildingState.Priority.LOW))
	sim.run_ticks(SimFixture.ticks(2))
	assert_int(mill.workers.size()).is_equal(1)
	assert_int(bakery.workers.size()).is_equal(0)


func test_priority_needs_a_workplace() -> void:
	var sim := SimFixture.make_sim()
	var well := SimFixture.place(sim, &"well", Vector2i(4, 4))
	assert_str(String(sim.execute(SetPriorityCommand.new(well.id, 0)))).is_equal("no_worker_slot")


func _taxed_town(rate: int) -> Simulation:
	var sim := SimFixture.make_sim()
	sim.treasury.gold = 0
	sim.execute(SetTaxRateCommand.new(rate))
	for x: int in [2, 5, 8]:
		SimFixture.house(sim, Vector2i(x, 8))
	SimFixture.place(sim, &"well", Vector2i(6, 12))
	sim.run_ticks(SimFixture.ticks(120))
	return sim


func test_houses_pay_taxes_and_the_rate_matters() -> void:
	var low := _taxed_town(Treasury.TaxRate.LOW)
	var normal := _taxed_town(Treasury.TaxRate.NORMAL)
	var high := _taxed_town(Treasury.TaxRate.HIGH)
	# 12 peasants x 0.25 gold a minute, scaled by happiness, for 2 minutes.
	assert_int(normal.treasury.gold).is_between(3, 7)
	assert_int(low.treasury.gold).is_less(normal.treasury.gold)
	assert_int(high.treasury.gold).is_greater(normal.treasury.gold)
	var hut_low := low.province.buildings.get_building(low.province.grid.occupant(Vector2i(2, 8)))
	var hut_high := high.province.buildings.get_building(high.province.grid.occupant(Vector2i(2, 8)))
	assert_float(hut_low.house.happiness).is_greater(hut_high.house.happiness)


func test_buildings_cost_gold_and_give_it_back() -> void:
	var sim := SimFixture.make_sim()
	sim.treasury.gold = 20
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"brewery", Vector2i(10, 10))))).is_equal("not_enough_gold")
	sim.treasury.gold = 50
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"brewery", Vector2i(10, 10))))).is_equal("")
	assert_int(sim.treasury.gold).is_equal(20)
	# Cancelled before any work: all the gold comes back.
	var site := sim.province.grid.occupant(Vector2i(10, 10))
	assert_str(String(sim.execute(DemolishCommand.new(site)))).is_equal("")
	assert_int(sim.treasury.gold).is_equal(50)
	# A finished building gives back half.
	var brewery := SimFixture.place(sim, &"brewery", Vector2i(10, 10))
	assert_int(sim.treasury.gold).is_equal(50)
	sim.execute(DemolishCommand.new(brewery.id))
	assert_int(sim.treasury.gold).is_equal(65)


func test_treasury_keeps_fractions() -> void:
	var t := Treasury.new()
	for i: int in 10:
		t.add(0.15)
	assert_int(t.gold).is_equal(1)
	var copy := Treasury.from_dict(t.to_dict())
	copy.add(0.5)
	assert_int(copy.gold).is_equal(2)


func test_workshops_leave_what_is_kept_for_building() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim, 12, 20)
	var stock: BuildingState = village["stock"]
	assert_str(String(sim.execute(SetKeepForBuildingCommand.new(&"wood", 10)))).is_equal("")
	var sawmill := SimFixture.place(sim, &"sawmill", Vector2i(14, 4))
	sim.run_ticks(SimFixture.ticks(120))
	# The sawmill took only the 2 logs above the 10 kept: at most 4 planks.
	assert_int(sim.province.goods_total(&"planks")).is_between(1, 4)
	assert_int(stock.stock.total(&"wood")).is_greater_equal(10)
	var worker := sim.province.agents.get_agent(sawmill.workers[0])
	assert_str(String(worker.last_fail)).is_equal("kept_for_building")
	# Building sites still take the kept wood (the houses' reserve is lowered too).
	sim.execute(SetReserveCommand.new(stock.id, &"wood", 0))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"well", Vector2i(14, 10))))).is_equal("")
	var well := sim.province.buildings.get_building(sim.province.grid.occupant(Vector2i(14, 10)))
	assert_bool(SimFixture.run_until(sim, func() -> bool: return well.is_complete(), 120)).is_true()
	# Nothing kept any more: the sawmill saws the rest.
	var planks := sim.province.goods_total(&"planks")
	sim.execute(SetKeepForBuildingCommand.new(&"wood", 0))
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(sim.province.goods_total(&"planks")).is_greater(planks)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_keep_for_building_command_is_validated() -> void:
	var sim := SimFixture.make_sim()
	assert_str(String(sim.execute(SetKeepForBuildingCommand.new(&"gold_bars", 3)))).is_equal("unknown_good")
	assert_str(String(sim.execute(SetKeepForBuildingCommand.new(&"wood", -1)))).is_equal("invalid_value")
	assert_str(String(sim.execute(SetKeepForBuildingCommand.new(&"wood", 61)))).is_equal("invalid_value")
	assert_str(String(sim.execute(SetKeepForBuildingCommand.new(&"wood", 15)))).is_equal("")
	assert_int(sim.province.keep_for_building[&"wood"]).is_equal(15)
	sim.execute(SetKeepForBuildingCommand.new(&"wood", 0))
	assert_bool(sim.province.keep_for_building.has(&"wood")).is_false()
