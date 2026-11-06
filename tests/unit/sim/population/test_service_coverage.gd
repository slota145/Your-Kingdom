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


## M4b-3: only sources whose reach a change touches measure again, and the result is the
## same as measuring every source from scratch (a loaded game sees the same coverage).
func test_incremental_coverage_matches_a_fresh_one() -> void:
	var sim := SimFixture.make_sim(Vector2i(64, 48))
	var province := sim.province
	SimFixture.place(sim, &"well", Vector2i(10, 10))
	SimFixture.place(sim, &"well", Vector2i(50, 30))
	SimFixture.place(sim, &"church", Vector2i(30, 20))
	province.coverage.update(province)
	# A road near the first well and the church, a wall near the second well, a field far away.
	var road: Array[Vector2i] = []
	for x: int in range(11, 28):
		road.append(Vector2i(x, 11))
	sim.execute(BuildRoadCommand.new(road))
	for y: int in range(25, 36):
		province.grid.set_blocked(Vector2i(47, y), true)
		province.refresh_tile(Vector2i(47, y))
	province.coverage.update(province)
	var fresh := ServiceCoverage.new()
	fresh.setup(province.grid.size)
	fresh.cost_map = province.coverage.cost_map.duplicate()
	fresh.update(province)
	for service: StringName in [&"well", &"church"]:
		assert_array(Array(province.coverage.map_of(service))).is_equal(Array(fresh.map_of(service)))


## M4b-3: trees slow people down but do not shorten the reach of services, so cutting them
## near the town does not make the services measure again.
func test_trees_do_not_change_reach() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var province := sim.province
	var well := SimFixture.place(sim, &"well", Vector2i(10, 10))
	var r := well.def.service_radius
	SimFixture.plant_trees(sim, Rect2i(11, 6, 10, 10))
	province.coverage.update(province)
	assert_bool(province.coverage.covers(&"well", Vector2i(10 + r, 10), province.grid.size)).is_true()
	assert_bool(province.nav.get_cost(Vector2i(12, 10)) > 1.0).is_true()
	assert_bool(province.coverage._dirty_tiles.is_empty()).is_true()


## A tavern without drinks stops serving and serves again without measuring anew.
func test_service_switches_off_and_on() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var province := sim.province
	var tavern := SimFixture.place(sim, &"tavern", Vector2i(10, 10))
	tavern.serving_until = province.tick + 100
	province.coverage.update(province)
	var door := Vector2i(13, 11)
	assert_bool(province.coverage.covers(&"tavern", door, province.grid.size)).is_true()
	province.tick = tavern.serving_until
	province.coverage.update(province)
	assert_bool(province.coverage.covers(&"tavern", door, province.grid.size)).is_false()
	tavern.serving_until = province.tick + 100
	province.coverage.update(province)
	assert_bool(province.coverage.covers(&"tavern", door, province.grid.size)).is_true()
	province.remove_building(tavern.id)
	province.coverage.update(province)
	assert_bool(province.coverage.covers(&"tavern", door, province.grid.size)).is_false()
