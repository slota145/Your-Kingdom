extends GdUnitTestSuite
## M3: fields are 1x1 tiles placed around a farm; the farmer ploughs, sows, the grain grows
## in 3 stages, he reaps it, binds a sheaf and carries it to the storage.


func _farm_scene() -> Dictionary:
	var sim := SimFixture.make_sim()
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var farm := SimFixture.place(sim, &"farm", Vector2i(12, 12))
	var farmer := SimFixture.spawn(sim, &"farmer", farm.entrance_tile())
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
		if stock.stock.total(&"grain") > 0:
			break
	for activity: StringName in [&"plow", &"sow", &"harvest", &"bind"]:
		assert_bool(activities.has(activity)).override_failure_message("never " + activity).is_true()
	assert_array(stages).is_equal([1, 2, 3])
	assert_int(harvested).is_equal(1)
	assert_int(stock.stock.total(&"grain")).is_equal(1)
	assert_int(sim.province.fields.stage(tile, sim.clock.tick)).is_equal(FieldStore.Stage.FALLOW)


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
