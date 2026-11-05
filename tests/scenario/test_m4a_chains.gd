extends GdUnitTestSuite
## M4a DoD: every new chain runs on its own and every unit comes from its visible steps
## (event counters): planks, stone, fish, hops and beer.


## Runs [param seconds] and counts produced/gathered/harvested goods by id.
func _run_counting(sim: Simulation, seconds: float) -> Dictionary:
	var counts := {}
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] in [&"good_produced", &"good_gathered", &"good_harvested"]:
				var key := "%s:%s" % [e["type"], e["good"]]
				counts[key] = int(counts.get(key, 0)) + int(e["amount"])
	return counts


func _set_water(sim: Simulation, rect: Rect2i) -> void:
	var water := SimFixture.registry().get_terrain(&"water")
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			sim.province.grid.set_terrain(Vector2i(x, y), water.index)
			sim.province.refresh_tile(Vector2i(x, y))


func test_sawmill_turns_logs_into_planks() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var village := SimFixture.village(sim, 30, 20)
	SimFixture.place(sim, &"sawmill", Vector2i(14, 4))
	var wood_before := sim.province.goods_total(&"wood")
	var counts := _run_counting(sim, 180)
	var planks := int(counts.get("good_produced:planks", 0))
	print("sawmill in 3 min: ", counts)
	assert_int(planks).is_greater(5)
	assert_int(sim.province.goods_total(&"planks")).is_equal(planks)
	# One log gives two planks: the wood that is gone went into planks (plus a little firewood).
	assert_int(planks % 2).is_equal(0)
	assert_int(wood_before - sim.province.goods_total(&"wood")).is_greater_equal(planks / 2)
	assert_int((village["stock"] as BuildingState).stock.total(&"planks")).is_greater(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_quarry_breaks_stone_off_the_rocks() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	SimFixture.village(sim, 30, 20)
	SimFixture.place(sim, &"quarry", Vector2i(14, 4))
	var rock := SimFixture.registry().get_resource_node(&"rock")
	for x: int in range(20, 23):
		sim.province.resources.place(Vector2i(x, 8), rock)
		sim.province.refresh_tile(Vector2i(x, 8))
	var counts := _run_counting(sim, 180)
	var stone := int(counts.get("good_gathered:stone", 0))
	print("quarry in 3 min: ", counts)
	assert_int(stone).is_greater(5)
	assert_int(sim.province.goods_total(&"stone")).is_equal(stone)
	assert_int(sim.province.resources.amount(Vector2i(20, 8)) + sim.province.resources.amount(Vector2i(21, 8)) \
			+ sim.province.resources.amount(Vector2i(22, 8))).is_equal(3 * rock.amount - stone)


func test_fishing_hut_must_stand_near_water() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_set_water(sim, Rect2i(30, 0, 4, 40))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"fishing_hut", Vector2i(10, 10))))).is_equal("no_water_nearby")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"fishing_hut", Vector2i(24, 10))))).is_equal("")


func test_angler_catches_fish_at_the_shore() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	SimFixture.village(sim, 30, 20)
	_set_water(sim, Rect2i(22, 0, 4, 40))
	var hut := SimFixture.place(sim, &"fishing_hut", Vector2i(18, 4))
	var fish_before := sim.province.goods_total(&"fish")
	var shore := Agent.NO_TILE
	var counts := {}
	for i: int in SimFixture.ticks(180):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_produced" and e["good"] == &"fish":
				counts["fish"] = int(counts.get("fish", 0)) + int(e["amount"])
		var angler := sim.province.agents.get_agent(hut.workers[0]) if not hut.workers.is_empty() else null
		if angler != null and angler.activity == &"wait_bite":
			shore = angler.tile()
	print("angler in 3 min: ", counts)
	assert_int(int(counts.get("fish", 0))).is_greater(3)
	# Households eat a little meanwhile, never more than they had in the pantry.
	assert_int(sim.province.goods_total(&"fish")).is_between(int(counts["fish"]), int(counts["fish"]) + fish_before)
	# He waits for a bite on the bank, next to the water.
	assert_vector(shore).is_not_equal(Agent.NO_TILE)
	assert_vector(sim.province.shore_water(shore, &"water")).is_not_equal(Agent.NO_TILE)


func test_hop_farm_grows_hops_on_its_fields() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	SimFixture.village(sim, 30, 20)
	# A well keeps the village happy, so it keeps its workers for the 5 minutes.
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	var farm := SimFixture.place(sim, &"hop_farm", Vector2i(18, 14))
	for x: int in range(20, 24):
		assert_str(String(sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(x, 13))))).is_equal("")
	var counts := _run_counting(sim, 300)
	print("hop farm in 5 min: ", counts)
	assert_int(int(counts.get("good_harvested:hops", 0))).is_greater_equal(4)
	assert_int(int(counts.get("good_harvested:grain", 0))).is_equal(0)


func test_brewery_brews_beer_from_grain_and_hops() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var village := SimFixture.village(sim, 30, 20)
	var stock: BuildingState = village["stock"]
	stock.stock.add(&"grain", 10)
	stock.stock.add(&"hops", 10)
	SimFixture.place(sim, &"brewery", Vector2i(14, 4))
	var beer_before := sim.province.goods_total(&"beer")
	var counts := _run_counting(sim, 240)
	var beer := int(counts.get("good_produced:beer", 0))
	print("brewery in 4 min: ", counts)
	assert_int(beer).is_greater_equal(6)
	assert_int(beer % 2).is_equal(0)
	# 1 grain + 1 hops -> 2 beer; nothing appears or vanishes.
	var batches := beer / 2
	assert_int(sim.province.goods_total(&"hops")).is_equal(10 - batches)
	assert_int(sim.province.goods_total(&"grain")).is_equal(10 - batches)
	assert_int(sim.province.goods_total(&"beer")).is_between(beer, beer + beer_before)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_brewer_without_hops_keeps_one_grain_and_waits() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var village := SimFixture.village(sim, 30, 20)
	var stock: BuildingState = village["stock"]
	stock.stock.add(&"grain", 10)
	var brewery := SimFixture.place(sim, &"brewery", Vector2i(14, 4))
	sim.run_ticks(SimFixture.ticks(90))
	# The first grain waits in the brewery; no more is fetched while hops are missing.
	assert_int(brewery.supply.total(&"grain")).is_equal(1)
	assert_int(stock.stock.total(&"grain")).is_equal(9)
	var brewer := sim.province.agents.get_agent(brewery.workers[0])
	assert_str(String(brewer.last_fail_good)).is_equal("hops")
	# Hops arrive: brewing starts, using the grain already there.
	stock.stock.add(&"hops", 1)
	var beer := sim.province.goods_total(&"beer")
	var brewed := SimFixture.run_until(sim, func() -> bool: return sim.province.goods_total(&"beer") >= beer + 1, 60)
	assert_bool(brewed).is_true()
	assert_int(sim.province.goods_total(&"grain")).is_equal(9)
	assert_int(sim.province.goods_total(&"hops")).is_equal(0)


func test_brewery_inputs_survive_save_and_demolition() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var village := SimFixture.village(sim, 30, 20)
	(village["stock"] as BuildingState).stock.add(&"grain", 10)
	var brewery := SimFixture.place(sim, &"brewery", Vector2i(14, 4))
	sim.run_ticks(SimFixture.ticks(60))
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())), SimFixture.registry())
	assert_int(loaded.province.buildings.get_building(brewery.id).supply.total(&"grain")).is_equal(1)
	var grain := sim.province.goods_total(&"grain")
	sim.execute(DemolishCommand.new(brewery.id))
	assert_int(sim.province.goods_total(&"grain")).is_equal(grain)
