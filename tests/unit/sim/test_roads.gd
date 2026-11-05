extends GdUnitTestSuite
## M3: dirt roads make walking about 50% faster (GDD §5.2).


func _walk_time(with_road: bool) -> int:
	var sim := SimFixture.make_sim()
	if with_road:
		var tiles: Array[Vector2i] = []
		for x: int in range(2, 30):
			tiles.append(Vector2i(x, 10))
		sim.execute(BuildRoadCommand.new(tiles))
	var agent := SimFixture.spawn(sim, &"porter", Vector2i(2, 10))
	for i: int in 2000:
		if Movement.walk(sim.province, agent, Vector2i(29, 10)) == TaskStep.Status.DONE:
			return i
		Movement.serve_paths(sim.province)
		Movement.move_all(sim.province)
	return -1


func test_road_is_about_half_again_as_fast() -> void:
	var plain := _walk_time(false)
	var road := _walk_time(true)
	assert_int(road).is_greater(0)
	assert_float(float(plain) / road).is_between(1.4, 1.6)


func test_road_rules() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var blocked: Array[Vector2i] = [Vector2i(3, 3)]
	assert_str(String(sim.execute(BuildRoadCommand.new(blocked)))).is_equal("tile_occupied")
	var free: Array[Vector2i] = [Vector2i(3, 3), Vector2i(10, 10)]
	assert_str(String(sim.execute(BuildRoadCommand.new(free)))).is_equal("")
	assert_int(sim.province.grid.road_count()).is_equal(1)
	assert_str(String(sim.province.placement_error(SimFixture.registry().get_building(&"well"),
			Vector2i(10, 10)))).is_equal("tile_occupied")
	var state := SimCodec.canonical(sim.to_dict())
	var loaded := Simulation.from_dict(JSON.parse_string(state), SimFixture.registry())
	assert_bool(loaded.province.grid.has_road(Vector2i(10, 10))).is_true()
	assert_float(loaded.province.nav.get_cost(Vector2i(10, 10))).is_equal_approx(ProvinceSim.ROAD_COST, 0.001)
