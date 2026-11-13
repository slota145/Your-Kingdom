extends GdUnitTestSuite
## M3: fields are 1x1 tiles placed around a farm; the farmer ploughs, sows, the grain grows
## in 3 stages, he reaps it, binds a sheaf and carries it to the storage.


func _farm_scene() -> Dictionary:
	var sim := SimFixture.make_sim()
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var farm := SimFixture.place(sim, &"farm", Vector2i(12, 12))
	var farmer := SimFixture.spawn(sim, &"farmer", farm.entrance_tile())
	# UI-2 part 2: the worker leaves what he made on his yard, a porter takes it to the storage.
	SimFixture.spawn(sim, &"porter", Vector2i(6, 8))
	sim.execute(AssignWorkerCommand.new(farmer.id, farm.id))
	return {"sim": sim, "stock": stock, "farm": farm, "farmer": farmer}


func test_field_placement_rules() -> void:
	var scene := _farm_scene()
	var sim: Simulation = scene["sim"]
	var farm: BuildingState = scene["farm"]
	assert_str(String(sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(14, 12))))).is_equal("")
	assert_str(String(sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(14, 12))))).is_equal("tile_occupied")
	assert_str(String(sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(12, 12))))).is_equal("tile_occupied")
	assert_str(String(sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(25, 25))))).is_equal("out_of_range")
	assert_str(String(sim.execute(PlaceFieldCommand.new(scene["stock"].id, Vector2i(9, 9))))).is_equal("not_a_farm")
	var placed := 1
	for y: int in range(8, 18):
		for x: int in range(8, 18):
			if sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(x, y))) == &"":
				placed += 1
	assert_int(placed).is_equal(16)
	assert_int(sim.province.fields.tiles_of(farm.id).size()).is_equal(16)
	assert_str(String(sim.province.placement_error(SimFixture.registry().get_building(&"well"),
			Vector2i(14, 12)))).is_equal("tile_occupied")


func test_field_cycle_ends_with_a_sheaf_in_the_storage() -> void:
	var scene := _farm_scene()
	var sim: Simulation = scene["sim"]
	var farm: BuildingState = scene["farm"]
	var stock: BuildingState = scene["stock"]
	var tile := Vector2i(14, 12)
	sim.execute(PlaceFieldCommand.new(farm.id, tile))
	var activities := {}
	var stages: Array[int] = []
	var harvested := 0
	for i: int in SimFixture.ticks(200):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"good_harvested":
				harvested += int(event["amount"])
		var agent: Agent = scene["farmer"]
		activities[agent.activity] = true
		var g := sim.province.fields.growth_stage(tile, sim.clock.tick)
		if g > 0 and not stages.has(g):
			stages.append(g)
		# UI-2 part 2: the farmer leaves the sheaf on the farm's yard (a porter takes it on).
		if farm.yard.total(&"grain") + stock.stock.total(&"grain") > 0:
			break
	for activity: StringName in [&"plow", &"sow", &"harvest", &"bind"]:
		assert_bool(activities.has(activity)).override_failure_message("never " + activity).is_true()
	assert_array(stages).is_equal([1, 2, 3])
	assert_int(harvested).is_equal(1)
	assert_int(farm.yard.total(&"grain") + stock.stock.total(&"grain")).is_equal(1)
	assert_int(sim.province.fields.stage(tile, sim.clock.tick)).is_equal(FieldStore.Stage.FALLOW)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return stock.stock.total(&"grain") >= 1, 60.0)).is_true()


func test_removing_a_field_under_the_farmer_releases_it() -> void:
	var scene := _farm_scene()
	var sim: Simulation = scene["sim"]
	var farm: BuildingState = scene["farm"]
	var tile := Vector2i(14, 12)
	sim.execute(PlaceFieldCommand.new(farm.id, tile))
	SimFixture.run_until(sim, func() -> bool: return sim.province.fields.claimant(tile) != 0, 10)
	sim.execute(RemoveFieldCommand.new(tile))
	sim.run_ticks(50)
	assert_array(Array(sim.province.dangling_holds())).is_empty()
	assert_bool(sim.province.nav.is_walkable(tile)).is_true()


func test_demolishing_the_farm_removes_its_fields() -> void:
	var scene := _farm_scene()
	var sim: Simulation = scene["sim"]
	var farm: BuildingState = scene["farm"]
	sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(14, 12)))
	sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(15, 12)))
	sim.run_ticks(30)
	sim.execute(DemolishCommand.new(farm.id))
	assert_int(sim.province.fields.count()).is_equal(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_fields_slow_walking_and_roads_speed_it_up() -> void:
	var sim := SimFixture.make_sim()
	var farm := SimFixture.place(sim, &"farm", Vector2i(12, 12))
	sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(14, 12)))
	assert_float(sim.province.nav.get_cost(Vector2i(14, 12))).is_equal_approx(ProvinceSim.FIELD_COST, 0.001)
	var road: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
	assert_str(String(sim.execute(BuildRoadCommand.new(road)))).is_equal("")
	assert_float(sim.province.nav.get_cost(Vector2i(5, 5))).is_equal_approx(ProvinceSim.ROAD_COST, 0.001)
	assert_str(String(sim.province.road_error(Vector2i(14, 12)))).is_equal("tile_occupied")
	sim.execute(RemoveRoadCommand.new(road))
	assert_float(sim.province.nav.get_cost(Vector2i(5, 5))).is_equal_approx(1.0, 0.001)


## E1 part 2: the whole field grows together. Sown tiles wait until the last tile is sown,
## then start at once and ripen together; meanwhile the farmer weeds.
func test_the_whole_field_starts_growing_after_the_last_tile_is_sown() -> void:
	var scene := _farm_scene()
	var sim: Simulation = scene["sim"]
	var farm: BuildingState = scene["farm"]
	var tiles: Array[Vector2i] = [Vector2i(14, 12), Vector2i(15, 12), Vector2i(14, 13), Vector2i(15, 13)]
	for tile: Vector2i in tiles:
		sim.execute(PlaceFieldCommand.new(farm.id, tile))
	var fields := sim.province.fields
	var saw_waiting := false
	var started := -1
	var weeded := false
	for i: int in SimFixture.ticks(200):
		sim.step()
		sim.events.drain()
		var waiting := 0
		var growing := 0
		for tile: Vector2i in tiles:
			if fields.is_waiting(tile):
				waiting += 1
			elif fields.is_growing(tile, sim.clock.tick):
				growing += 1
		# Never a mix: tiles wait together and then grow together.
		assert_bool(waiting > 0 and growing > 0).override_failure_message("waiting and growing at once").is_false()
		if waiting > 0:
			saw_waiting = true
			assert_int(fields.growth_stage(tiles[0], sim.clock.tick)).is_equal(0)
		if growing == tiles.size() and started < 0:
			started = sim.clock.tick
		if (scene["farmer"] as Agent).activity == &"weed":
			weeded = true
		if fields.stage(tiles[0], sim.clock.tick) == FieldStore.Stage.RIPE:
			break
	assert_bool(saw_waiting).is_true()
	assert_int(started).is_greater(0)
	assert_bool(weeded).override_failure_message("the farmer never weeded").is_true()
	# They ripen at the same tick.
	for tile: Vector2i in tiles:
		assert_int(fields.stage(tile, sim.clock.tick)).is_equal(FieldStore.Stage.RIPE)


func test_a_field_waits_no_longer_than_its_limit() -> void:
	var fields := FieldStore.new()
	fields.add(Vector2i(1, 1), 5)
	fields.add(Vector2i(2, 1), 5)
	fields.sow(Vector2i(1, 1), 100, 900)
	assert_array(Array(fields.start_if_ready(5, 100 + SimClock.seconds_to_ticks(10.0)))).is_empty()
	assert_bool(fields.is_waiting(Vector2i(1, 1))).is_true()
	var later := 100 + SimClock.seconds_to_ticks(FieldStore.WAIT_LIMIT_SECONDS)
	assert_array(Array(fields.start_if_ready(5, later))).is_equal([Vector2i(1, 1)])
	assert_int(fields.stage(Vector2i(1, 1), later + 899)).is_equal(FieldStore.Stage.SOWN)
	assert_int(fields.stage(Vector2i(1, 1), later + 900)).is_equal(FieldStore.Stage.RIPE)


func test_removing_the_last_unsown_tile_starts_the_rest() -> void:
	var scene := _farm_scene()
	var sim: Simulation = scene["sim"]
	var farm: BuildingState = scene["farm"]
	assert_str(String(sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(14, 12))))).is_empty()
	assert_str(String(sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(16, 14))))).is_empty()
	var fields := sim.province.fields
	fields.sow(Vector2i(14, 12), sim.clock.tick, 900)
	assert_bool(fields.is_waiting(Vector2i(14, 12))).is_true()
	sim.execute(RemoveFieldCommand.new(Vector2i(16, 14)))
	assert_bool(fields.is_growing(Vector2i(14, 12), sim.clock.tick)).is_true()


func test_extra_yield_adds_a_unit_now_and_then() -> void:
	var data := SimFixture.registry()
	var farm := BuildingState.new(1, data.get_building(&"farm"), Vector2i.ZERO)
	var step := farm.def.recipe.steps[0] as FieldStepDef
	assert_float(step.harvest_extra).is_equal_approx(0.2, 0.0001)
	var total := 0
	for i: int in 10:
		total += farm.take_field_yield(step)
	assert_int(total).is_equal(12)
	assert_float(farm.field_yield_carry).is_equal_approx(0.0, 0.0001)
	farm.take_field_yield(step)
	var loaded := BuildingState.from_dict(farm.to_dict(), data)
	assert_float(loaded.field_yield_carry).is_equal_approx(0.2, 0.0001)
