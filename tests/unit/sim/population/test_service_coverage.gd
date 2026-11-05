extends GdUnitTestSuite
## M3: a well reaches houses by path length (GDD §3.2), so walls and water shorten its
## reach and roads lengthen it.


func test_reach_is_measured_along_paths() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var well := SimFixture.place(sim, &"well", Vector2i(10, 10))
	var province := sim.province
	province.coverage.update(province)
	var size := province.grid.size
	var r := well.def.service_radius
	assert_bool(province.coverage.covers(&"well", Vector2i(10 + r, 10), size)).is_true()
	assert_bool(province.coverage.covers(&"well", Vector2i(10 + r + 1, 10), size)).is_false()
	# A wall right next to the well: the other side is now far away.
	for y: int in range(0, 30):
		province.grid.set_blocked(Vector2i(11, y), true)
		province.refresh_tile(Vector2i(11, y))
	province.coverage.update(province)
	assert_bool(province.coverage.covers(&"well", Vector2i(13, 10), size)).is_false()


func test_road_extends_reach() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var well := SimFixture.place(sim, &"well", Vector2i(10, 10))
	var far := Vector2i(10 + well.def.service_radius + 5, 10)
	sim.province.coverage.update(sim.province)
	assert_bool(sim.province.coverage.covers(&"well", far, sim.province.grid.size)).is_false()
	var road: Array[Vector2i] = []
	for x: int in range(11, 40):
		road.append(Vector2i(x, 10))
	sim.execute(BuildRoadCommand.new(road))
	sim.province.coverage.update(sim.province)
	assert_bool(sim.province.coverage.covers(&"well", far, sim.province.grid.size)).is_true()
