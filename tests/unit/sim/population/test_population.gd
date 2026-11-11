extends GdUnitTestSuite
## M3: households eat, fetch supplies, get happy, grow, decline; newcomers walk in; free
## residents are handed to buildings missing workers.


func _count(sim: Simulation, kind: StringName) -> int:
	var n := 0
	for agent: Agent in sim.province.agents.all():
		if agent.kind == kind:
			n += 1
	return n


func test_free_residents_staff_the_town_hall_first() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.village(sim)
	var mill := SimFixture.place(sim, &"mill", Vector2i(16, 16))
	sim.run_ticks(Population.UPDATE_TICKS + 1)
	# 8 residents -> 4 workers: builder + 2 porters first, then the miller.
	assert_int(_count(sim, &"builder")).is_equal(1)
	assert_int(_count(sim, &"porter")).is_equal(2)
	assert_int(mill.workers.size()).is_equal(1)
	var bakery := SimFixture.place(sim, &"bakery", Vector2i(20, 16))
	sim.run_ticks(Population.UPDATE_TICKS)
	assert_int(bakery.workers.size()).is_equal(0)
	assert_int(Population.workforce(sim.province)).is_equal(4)


func test_workers_lose_their_jobs_when_the_house_empties() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim)
	sim.run_ticks(Population.UPDATE_TICKS + 1)
	var houses: Array = village["houses"]
	for house: BuildingState in houses:
		house.house.residents = 0
	sim.run_ticks(Population.UPDATE_TICKS)
	assert_int(_count(sim, &"porter") + _count(sim, &"builder")).is_equal(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_householder_fetches_bread_when_pantry_runs_low() -> void:
	var sim := SimFixture.make_sim()
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	stock.stock.add(&"bread", 10)
	stock.stock.add(&"wood", 10)
	var hut := SimFixture.house(sim, Vector2i(12, 12), 4, false)
	var saw_householder := false
	for i: int in SimFixture.ticks(60):
		sim.step()
		sim.events.drain()
		if _count(sim, Population.HOUSEHOLDER_KIND) > 0:
			saw_householder = true
	assert_bool(saw_householder).is_true()
	assert_int(hut.supply.total(&"bread")).is_greater(0)
	assert_int(hut.supply.total(&"wood")).is_greater(0)
	# Householders go back inside when done.
	assert_int(_count(sim, Population.HOUSEHOLDER_KIND)).is_equal(0)


func test_households_eat_their_pantry() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.house(sim, Vector2i(12, 12), 4)
	var bread := hut.supply.total(&"bread")
	# 4 residents x 0.1 bread per minute: 1 loaf in 2.5 minutes.
	sim.run_ticks(SimFixture.ticks(160))
	assert_int(hut.supply.total(&"bread")).is_equal(bread - 1)


func test_happiness_follows_satisfied_needs() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.house(sim, Vector2i(12, 12), 4)
	sim.run_ticks(SimFixture.ticks(60))
	# Food and firewood but no well, a basic need: it counts against the house,
	# 35 + 25 - 25.
	assert_float(hut.house.happiness).is_equal_approx(35.0, 0.01)
	SimFixture.place(sim, &"well", Vector2i(16, 12))
	sim.run_ticks(SimFixture.ticks(40))
	# Food, firewood and the well, no chapel: 35 + 25 + 25.
	assert_float(hut.house.happiness).is_equal_approx(85.0, 0.01)
	assert_bool(hut.house.satisfied[&"well_water"]).is_true()
	# The chapel is an extra need: it adds happiness but does not block upgrades.
	SimFixture.place(sim, &"chapel", Vector2i(12, 16))
	sim.run_ticks(SimFixture.ticks(30))
	assert_float(hut.house.happiness).is_equal_approx(100.0, 0.01)


func test_newcomers_walk_in_to_free_places() -> void:
	var sim := SimFixture.make_sim()
	sim.province.entry_tile = Vector2i(0, 20)
	var hut := SimFixture.house(sim, Vector2i(12, 12), 0)
	# With every basic need met (a house without a well turns unhappy and stops attracting).
	SimFixture.place(sim, &"well", Vector2i(16, 12))
	var settlers := 0
	for i: int in SimFixture.ticks(120):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"agent_spawned" and event["kind"] == Population.SETTLER_KIND:
				settlers += 1
				assert_vector(event["tile"]).is_equal(Vector2i(0, 20))
	assert_int(settlers).is_equal(4)
	assert_int(hut.house.residents).is_equal(4)
	assert_int(hut.house.incoming).is_equal(0)
	assert_int(_count(sim, Population.SETTLER_KIND)).is_equal(0)


func test_unhappy_house_gets_no_newcomers() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.house(sim, Vector2i(12, 12), 1, false)
	# No food, firewood or well: far too unhappy even for the half-house newcomers.
	hut.house.happiness = 0.0
	sim.run_ticks(SimFixture.ticks(120))
	assert_float(hut.house.happiness).is_less(Population.IMMIGRATION_MIN_HAPPINESS)
	assert_int(hut.house.residents + hut.house.incoming).is_equal(1)


func test_hut_upgrades_after_needs_are_met_and_planks_are_delivered() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim, 40, 40)
	var houses: Array = village["houses"]
	var hut: BuildingState = houses[0]
	var stock: BuildingState = village["stock"]
	stock.stock.add(&"planks", 8)
	_stock_burgher_goods(stock)
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	var upgraded := SimFixture.run_until(sim, func() -> bool: return hut.house.level == 2, 200)
	assert_bool(upgraded).is_true()
	assert_int(hut.capacity()).is_equal(8)
	assert_int(hut.supply.stack_limit).is_equal(4)
	assert_int(stock.stock.total(&"planks")).is_less_equal(4)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func _stock_burgher_goods(stock: BuildingState) -> void:
	stock.stock.add(&"fish", 10)
	stock.stock.add(&"beer", 10)


func test_hut_without_planks_does_not_upgrade() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim, 40, 40)
	var hut: BuildingState = (village["houses"] as Array)[0]
	_stock_burgher_goods(village["stock"])
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	sim.run_ticks(SimFixture.ticks(150))
	assert_int(hut.site_id).is_not_equal(0)
	assert_int(hut.house.level).is_equal(1)


func test_no_upgrade_while_the_town_lacks_burgher_goods() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim, 40, 40)
	var stock: BuildingState = village["stock"]
	stock.stock.add(&"planks", 8)
	stock.stock.add(&"fish", 10)
	var hut: BuildingState = (village["houses"] as Array)[0]
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	# Peasant needs are met, but there is no beer for burghers: the hut waits.
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(hut.site_id).is_equal(0)
	assert_int(hut.house.met_seconds).is_greater(Population.UPGRADE_AFTER)
	stock.stock.add(&"beer", 10)
	var upgraded := SimFixture.run_until(sim, func() -> bool: return hut.house.level == 2, 60)
	assert_bool(upgraded).is_true()


func test_house_keeps_its_level_but_loses_residents_in_a_shortage() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.house(sim, Vector2i(12, 12), 8, false)
	hut.house.level = 2
	hut.house.happiness = 80.0
	var warned := false
	var left := 0
	for i: int in SimFixture.ticks(Population.LEAVE_AFTER + 4 * Population.LEAVE_EVERY + 5):
		sim.step()
		for event: Dictionary in sim.events.drain():
			warned = warned or event["type"] == &"house_warning"
			if event["type"] == &"resident_left":
				left += 1
	assert_bool(warned).is_true()
	# Gentle: happiness sinks at 1 point/s; after 5 minutes of shortage one resident leaves
	# every 3 minutes, but half of the places (the core) always stay: 5 chances, 4 leave.
	assert_int(hut.house.level).is_equal(2)
	assert_float(hut.house.happiness).is_less(Population.LEAVE_BELOW)
	assert_int(left).is_equal(4)
	assert_int(hut.house.residents).is_equal(Population.core_residents(hut))
	assert_int(hut.house.residents).is_equal(4)
	# Nobody leaves while the house is still fairly happy.
	var calm := SimFixture.house(sim, Vector2i(16, 16), 4, false)
	calm.house.happiness = 100.0
	calm.house.unmet_seconds = Population.LEAVE_AFTER - 1
	sim.run_ticks(SimFixture.ticks(2))
	assert_int(calm.house.residents).is_equal(4)


func test_house_with_a_shortage_fills_up_to_half() -> void:
	var sim := SimFixture.make_sim()
	sim.province.entry_tile = Vector2i(0, 20)
	# Food and firewood, no well: 35 happiness, enough for newcomers up to half of the hut.
	var hut := SimFixture.house(sim, Vector2i(12, 12), 1)
	hut.house.happiness = 35.0
	sim.run_ticks(SimFixture.ticks(120))
	assert_float(hut.house.happiness).is_less(Population.IMMIGRATION_MIN_HAPPINESS)
	assert_int(hut.house.residents).is_equal(2)
	assert_int(hut.house.incoming).is_equal(0)


func test_unhappy_workers_work_slower() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.house(sim, Vector2i(12, 12), 4)
	hut.house.happiness = 0.0
	assert_float(Population.work_speed_of(hut)).is_equal_approx(Population.MIN_WORK_SPEED, 0.001)
	hut.house.happiness = Population.FULL_SPEED_HAPPINESS / 2.0
	assert_float(Population.work_speed_of(hut)).is_equal_approx(0.9, 0.001)
	hut.house.happiness = 100.0
	assert_float(Population.work_speed_of(hut)).is_equal_approx(1.0, 0.001)
	assert_float(Population.average_work_speed(sim.province)).is_equal_approx(1.0, 0.001)
	hut.house.happiness = 0.0
	assert_float(Population.average_work_speed(sim.province)).is_equal_approx(
			Population.MIN_WORK_SPEED, 0.001)


func test_house_with_needs_met_stops_losing_residents() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.house(sim, Vector2i(12, 12), 4, false)
	hut.house.happiness = 0.0
	sim.run_ticks(SimFixture.ticks(Population.LEAVE_AFTER + 10))
	var residents := hut.house.residents
	assert_int(residents).is_less(4)
	# Pantry filled and a well nearby: the shortage ends, happiness climbs, nobody else leaves.
	SimFixture.place(sim, &"well", Vector2i(10, 10))
	for good: StringName in hut.house_goods():
		hut.supply.add(good, hut.level_def().supply_units)
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(hut.house.residents).is_greater_equal(residents)
	assert_int(hut.house.unmet_seconds).is_equal(0)
	assert_float(hut.house.happiness).is_greater(Population.LEAVE_BELOW)


## E1: "Upgrade now" opens the upgrade site as soon as the needs are met, without the wait.
func test_upgrade_now_skips_the_wait() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim, 40, 40)
	var hut: BuildingState = (village["houses"] as Array)[0]
	var stock: BuildingState = village["stock"]
	stock.stock.add(&"planks", 8)
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	assert_str(String(sim.execute(UpgradeHouseCommand.new(hut.id)))).is_not_empty()
	# Needs met, but no burgher goods yet: the button stays blocked with a reason.
	var met := SimFixture.run_until(sim, func() -> bool: return hut.house.met_seconds > 2, 60)
	assert_bool(met).is_true()
	assert_str(String(Population.upgrade_blocker(sim.province, hut))).is_equal("house_next_goods_missing")
	_stock_burgher_goods(stock)
	assert_int(hut.house.met_seconds).is_less(Population.UPGRADE_AFTER)
	assert_str(String(sim.execute(UpgradeHouseCommand.new(hut.id)))).is_empty()
	assert_int(hut.site_id).is_not_equal(0)
	assert_str(String(Population.upgrade_blocker(sim.province, hut))).is_equal("upgrade_running")
	var upgraded := SimFixture.run_until(sim, func() -> bool: return hut.house.level == 2, 120)
	assert_bool(upgraded).is_true()
	assert_array(Array(sim.province.dangling_holds())).is_empty()
