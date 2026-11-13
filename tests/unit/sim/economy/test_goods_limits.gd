extends GdUnitTestSuite
## Goods limits (ROADMAP E5): the player sets the most units of a good the province should hold;
## at the limit (counted as in "Kingdom stocks") workshops and gatherers making it stop and
## start again once the stock drops below. Fields, pens and hives go on. Saved since v44.


func _limit(sim: Simulation, good: StringName, amount: int) -> void:
	assert_str(String(sim.execute(SetGoodsLimitCommand.new(good, amount)))).is_equal("")


func test_the_woodcutter_stops_at_the_limit_and_starts_again_below_it() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	var worker: Agent = scene["worker"]
	_limit(sim, &"wood", 3)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.kingdom_stock(&"wood") >= 3, 600)).is_true()
	# A cycle under way ends, then he waits by his hut.
	sim.run_ticks(SimFixture.ticks(120))
	var stock := sim.province.kingdom_stock(&"wood")
	assert_int(stock).is_less_equal(4)
	assert_int(sim.province.goods_total(&"wood")).is_less_equal(4)
	assert_str(String(worker.last_fail)).is_equal("goods_limit")
	assert_str(String(worker.last_fail_good)).is_equal("wood")
	assert_str(String(sim.province.limit_stopping(hut))).is_equal("wood")
	# Below the limit he goes back to the trees.
	var store: BuildingState = scene["stock"]
	hut.yard.remove(&"wood", hut.yard.total(&"wood"))
	store.stock.remove(&"wood", store.stock.total(&"wood"))
	sim.province.jobs.trim_yard_requests(sim.province)
	assert_str(String(sim.province.limit_stopping(hut))).is_equal("")
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.kingdom_stock(&"wood") >= 1, 300)).is_true()


func test_without_a_limit_nothing_stops() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.kingdom_stock(&"wood") >= 4, 900)).is_true()
	assert_str(String(sim.province.limit_stopping(scene["hut"]))).is_equal("")


func test_the_sawmill_stops_at_the_planks_limit_counting_its_yard() -> void:
	var sim := SimFixture.make_sim()
	var store := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	store.stock.add(&"wood", 20)
	var mill := SimFixture.place(sim, &"sawmill", Vector2i(12, 6))
	var sawyer := SimFixture.spawn(sim, &"sawyer", mill.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(sawyer.id, mill.id)))).is_equal("")
	_limit(sim, &"planks", 2)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.kingdom_stock(&"planks") >= 2, 600)).is_true()
	sim.run_ticks(SimFixture.ticks(180))
	# One cycle may finish over the limit (a cycle gives up to 2 planks).
	assert_int(sim.province.kingdom_stock(&"planks")).is_less_equal(4)
	assert_int(store.stock.total(&"wood")).is_greater_equal(14)
	assert_str(String(sawyer.last_fail)).is_equal("goods_limit")
	# The planks on the yard by the sawmill count too.
	assert_int(sim.province.kingdom_stock(&"planks")).is_equal(
			store.stock.total(&"planks") + mill.yard.total(&"planks"))
	# Removing the limit sets it going again.
	_limit(sim, &"planks", -1)
	assert_bool(sim.province.goods_limits.has(&"planks")).is_false()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return store.stock.total(&"wood") < 14, 600)).is_true()


func test_a_blacksmith_taking_turns_skips_a_recipe_at_its_limit() -> void:
	var sim := SimFixture.make_sim()
	var smithy := SimFixture.place(sim, &"blacksmith", Vector2i(12, 6))
	var choices := smithy.def.recipe_choices
	assert_int(choices.size()).is_greater(1)
	var last := choices[choices.size() - 1]
	for recipe: RecipeDef in choices:
		if recipe != last:
			for good: StringName in BuildingState.recipe_goods(recipe, sim.data):
				sim.province.goods_limits[good] = 0
	for i: int in choices.size() * 2:
		assert_object(sim.province.next_recipe(smithy)).is_same(last)
	assert_str(String(sim.province.limit_stopping(smithy))).is_equal("")
	for good: StringName in BuildingState.recipe_goods(last, sim.data):
		sim.province.goods_limits[good] = 0
	assert_object(sim.province.next_recipe(smithy)).is_null()
	assert_str(String(sim.province.limit_stopping(smithy))).is_not_equal("")
	# Set to one recipe by the player: only that one counts.
	smithy.recipe_mode = 0
	sim.province.goods_limits.clear()
	for good: StringName in BuildingState.recipe_goods(choices[1], sim.data):
		sim.province.goods_limits[good] = 0
	assert_object(sim.province.next_recipe(smithy)).is_same(choices[0])


func test_fields_pens_and_foresters_never_stop() -> void:
	var sim := SimFixture.make_sim()
	for id: StringName in [&"farm", &"pigsty", &"apiary", &"forester", &"orchard"]:
		var def := sim.data.get_building(id)
		assert_object(def).is_not_null()
		assert_bool(ProvinceSim.limits_apply(def)).is_false()
	for id: StringName in [&"woodcutter", &"sawmill", &"bakery", &"quarry", &"hunter_lodge"]:
		assert_bool(ProvinceSim.limits_apply(sim.data.get_building(id))).is_true()
	sim.province.goods_limits[&"grain"] = 0
	var farm := SimFixture.place(sim, &"farm", Vector2i(12, 6))
	assert_str(String(sim.province.limit_stopping(farm))).is_equal("")


func test_the_simplified_mode_keeps_the_limit() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	_limit(sim, &"wood", 2)
	var abstract := ProvinceAbstract.freeze(sim.province, sim.province.tick)
	var tick := sim.province.tick
	for second: int in 900:
		tick += ProvinceAbstract.STEP_TICKS
		abstract.step(tick)
	assert_int(abstract.detail.kingdom_stock(&"wood")).is_between(2, 3)
	assert_str(String(abstract.detail.limit_stopping(scene["hut"]))).is_equal("wood")


func test_the_command_checks_its_good_and_amount() -> void:
	var sim := SimFixture.make_sim()
	assert_str(String(sim.execute(SetGoodsLimitCommand.new(&"no_such_good", 5)))).is_equal("unknown_good")
	assert_str(String(sim.execute(SetGoodsLimitCommand.new(&"wood", 1000)))).is_equal("invalid_value")
	var live: StringName = &""
	for good: GoodDef in sim.data.goods():
		if good.is_live():
			live = good.id
			break
	if live != &"":
		assert_str(String(sim.execute(SetGoodsLimitCommand.new(live, 5)))).is_equal("not_limited")
	_limit(sim, &"wood", 0)
	assert_int(sim.province.goods_limits[&"wood"]).is_equal(0)


func test_limits_survive_save_and_load() -> void:
	var sim := SimFixture.make_sim()
	_limit(sim, &"planks", 100)
	_limit(sim, &"bread", 40)
	var text := JSON.stringify(sim.to_dict(), "", false, true)
	var loaded := Simulation.from_dict(JSON.parse_string(text), SimFixture.registry())
	assert_int(loaded.province.goods_limits.size()).is_equal(2)
	assert_int(loaded.province.goods_limits[&"planks"]).is_equal(100)
	assert_int(loaded.province.goods_limits[&"bread"]).is_equal(40)


func test_an_older_save_has_no_limits() -> void:
	var sim := SimFixture.make_sim()
	var old: Dictionary = JSON.parse_string(JSON.stringify(sim.to_dict()))
	var migrated := SaveMigrations.migrate(old, 43)
	var loaded := Simulation.from_dict(migrated, SimFixture.registry())
	assert_bool(loaded.province.goods_limits.is_empty()).is_true()
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(44)
