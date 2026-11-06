extends GdUnitTestSuite
## M4b-3: cobbles cost 1 stone per tile, porters bring it, the builder lays it tile by tile,
## and people walk faster on paving (+80%) than on dirt road (+50%) (GDD §5.2).


func _line(from_x: int, to_x: int, y: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x: int in range(from_x, to_x):
		tiles.append(Vector2i(x, y))
	return tiles


func _walk_time(paved: bool) -> int:
	var sim := SimFixture.make_sim()
	var tiles := _line(2, 30, 10)
	sim.execute(BuildRoadCommand.new(tiles))
	if paved:
		for tile: Vector2i in tiles:
			sim.province.grid.set_paved(tile, true)
			sim.province.refresh_tile(tile)
	var agent := SimFixture.spawn(sim, &"porter", Vector2i(2, 10))
	for i: int in 2000:
		if Movement.walk(sim.province, agent, Vector2i(29, 10)) == TaskStep.Status.DONE:
			return i
		Movement.serve_paths(sim.province)
		Movement.move_all(sim.province)
	return -1


func test_paving_is_faster_than_dirt_road() -> void:
	var dirt := _walk_time(false)
	var paved := _walk_time(true)
	assert_int(paved).is_greater(0)
	# Dirt road 0.67, paving 0.55: about 1.2x faster than dirt, 1.8x faster than grass.
	assert_float(float(dirt) / paved).is_between(1.12, 1.3)


func test_paving_rules() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var blocked: Array[Vector2i] = [Vector2i(3, 3)]
	assert_str(String(sim.execute(BuildPavingCommand.new(blocked)))).is_equal("tile_occupied")
	# Free ground becomes dirt road at once and waits for its stone.
	var tiles := _line(10, 14, 10)
	assert_str(String(sim.execute(BuildPavingCommand.new(tiles)))).is_equal("")
	assert_int(sim.province.grid.road_count()).is_equal(4)
	assert_int(sim.province.grid.paved_count()).is_equal(0)
	assert_int(sim.province.paving.size()).is_equal(1)
	assert_str(String(sim.execute(BuildPavingCommand.new(tiles)))).is_equal("already_ordered")
	var request: TransportRequest = sim.province.jobs.all()[0]
	assert_str(String(request.good)).is_equal("stone")
	assert_int(request.amount).is_equal(4)


func test_builder_lays_cobbles_with_stone_from_storage() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var scene := SimFixture.village(sim)
	var stock: BuildingState = scene["stock"]
	stock.stock.add(&"stone", 10)
	var tiles := _line(8, 14, 12)
	sim.execute(BuildPavingCommand.new(tiles))
	var province := sim.province
	var done := SimFixture.run_until(sim, func() -> bool: return province.grid.paved_count() == 6, 180.0)
	assert_bool(done).is_true()
	assert_int(stock.stock.total(&"stone")).is_equal(4)
	assert_int(province.paving.size()).is_equal(0)
	for tile: Vector2i in tiles:
		assert_float(province.nav.get_cost(tile)).is_equal_approx(ProvinceSim.PAVED_COST, 0.001)
	assert_array(Array(province.dangling_holds())).is_empty()


func test_no_stone_means_dirt_road_until_it_comes() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var scene := SimFixture.village(sim)
	var tiles := _line(8, 11, 12)
	sim.execute(BuildPavingCommand.new(tiles))
	sim.run_ticks(SimFixture.ticks(30))
	assert_int(sim.province.grid.paved_count()).is_equal(0)
	assert_bool(sim.province.grid.has_road(tiles[0])).is_true()
	(scene["stock"] as BuildingState).stock.add(&"stone", 3)
	var province := sim.province
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.grid.paved_count() == 3,
			120.0)).is_true()


func test_removing_ordered_road_shrinks_the_order() -> void:
	var sim := SimFixture.make_sim()
	var tiles := _line(10, 14, 10)
	sim.execute(BuildPavingCommand.new(tiles))
	var removed: Array[Vector2i] = [Vector2i(10, 10), Vector2i(11, 10)]
	sim.execute(RemoveRoadCommand.new(removed))
	var paving_site: PavingSite = sim.province.paving.values()[0]
	assert_array(paving_site.tiles).is_equal([Vector2i(12, 10), Vector2i(13, 10)])
	assert_int((sim.province.jobs.all()[0] as TransportRequest).amount).is_equal(2)
	var rest: Array[Vector2i] = [Vector2i(12, 10), Vector2i(13, 10)]
	sim.execute(RemoveRoadCommand.new(rest))
	assert_int(sim.province.paving.size()).is_equal(0)
	assert_int(sim.province.jobs.count()).is_equal(0)


func test_paving_survives_save_and_load() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var scene := SimFixture.village(sim)
	(scene["stock"] as BuildingState).stock.add(&"stone", 10)
	sim.execute(BuildPavingCommand.new(_line(8, 16, 12)))
	sim.run_ticks(SimFixture.ticks(40))
	var text := SimCodec.canonical(sim.to_dict())
	var loaded := Simulation.from_dict(JSON.parse_string(text), SimFixture.registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(text)
	var province := loaded.province
	assert_bool(SimFixture.run_until(loaded, func() -> bool: return province.grid.paved_count() == 8,
			240.0)).is_true()
	assert_float(province.nav.get_cost(Vector2i(8, 12))).is_equal_approx(ProvinceSim.PAVED_COST, 0.001)
