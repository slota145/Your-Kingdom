extends GdUnitTestSuite
## M4b-3 part 2: the 128x128 Lakeland map (a lake fed by a river, a stony hill with rocks),
## stony ground (no fields, a quarried rock leaves it) and a lake that counts as water.

var _sim: Simulation
var _problems: PackedStringArray


func before() -> void:
	_problems = PackedStringArray()
	var registry := SimFixture.registry()
	_sim = Simulation.from_map(registry, registry.get_map(&"lakeland"), 1, _problems)


func _count(predicate: Callable) -> int:
	var n := 0
	for y: int in _sim.province.grid.size.y:
		for x: int in _sim.province.grid.size.x:
			if predicate.call(Vector2i(x, y)):
				n += 1
	return n


func test_map_loads_with_lake_stony_hill_and_start_town() -> void:
	assert_array(Array(_problems)).is_empty()
	var province := _sim.province
	assert_vector(province.grid.size).is_equal(Vector2i(128, 128))
	var lake := _count(func(t: Vector2i) -> bool: return province.terrain_at(t).id == &"lake")
	var stony := _count(func(t: Vector2i) -> bool: return province.terrain_at(t).id == &"stony")
	var rocks := _count(func(t: Vector2i) -> bool: return province.resources.has_node(t, &"rock"))
	var trees := _count(func(t: Vector2i) -> bool: return province.resources.has_node(t, &"tree"))
	assert_int(lake).is_greater(500)
	assert_int(stony).is_greater(300)
	assert_int(rocks).is_greater(40)
	assert_int(trees).is_greater(1000)
	var kinds := {}
	for b: BuildingState in province.buildings.all():
		kinds[b.def.id] = int(kinds.get(b.def.id, 0)) + 1
	assert_dict(kinds).is_equal({&"town_hall": 1, &"stockpile": 1, &"hut": 3})


func test_settlers_reach_the_town_and_the_town_reaches_rocks_lake_and_forest() -> void:
	var province := _sim.province
	var hall: BuildingState = null
	for b: BuildingState in province.buildings.all():
		if b.def.id == &"town_hall":
			hall = b
	var door := hall.door_front_tile()
	assert_array(province.find_path(province.entry_tile, door)).is_not_empty()
	# The nearest rock, lake shore and tree must be reachable on foot and not too far away.
	for kind: String in ["rock", "lake", "tree"]:
		var best := 1 << 30
		var best_tile := Agent.NO_TILE
		for y: int in 128:
			for x: int in 128:
				var t := Vector2i(x, y)
				var hit := province.resources.has_node(t, StringName(kind)) if kind != "lake" \
						else province.terrain_at(t).id == &"lake"
				var d := (t - door).length_squared()
				if hit and d < best:
					best = d
					best_tile = t
		assert_int(best).override_failure_message("%s too far" % kind).is_less(40 * 40)
		var near := province.approach_tile(best_tile, door) if kind != "tree" else best_tile
		assert_array(province.find_path(door, near)).override_failure_message(kind).is_not_empty()


func test_stony_ground_takes_buildings_and_roads_but_no_fields() -> void:
	var sim := SimFixture.make_sim()
	var stony := SimFixture.registry().get_terrain(&"stony")
	for y: int in range(10, 20):
		for x: int in range(10, 15):
			sim.province.grid.set_terrain(Vector2i(x, y), stony.index)
	sim.province.rebuild_nav()
	assert_float(sim.province.nav.get_cost(Vector2i(12, 12))).is_equal_approx(1.2, 0.001)
	var farm := SimFixture.place(sim, &"farm", Vector2i(13, 14))
	assert_str(String(sim.province.field_error(farm.id, Vector2i(12, 12)))).is_equal("terrain_not_farmable")
	assert_str(String(sim.province.field_error(farm.id, Vector2i(16, 12)))).is_empty()
	assert_str(String(sim.province.road_error(Vector2i(11, 11)))).is_empty()


func test_quarried_rock_leaves_stony_ground() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.village(sim)
	var quarry := SimFixture.place(sim, &"quarry", Vector2i(14, 4))
	var rock := Vector2i(20, 4)
	SimFixture.place_nodes(sim, Rect2i(rock, Vector2i.ONE), &"rock")
	var worker := SimFixture.spawn(sim, &"stonecutter", quarry.entrance_tile())
	sim.execute(AssignWorkerCommand.new(worker.id, quarry.id))
	var province := sim.province
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.resources.is_depleted(rock),
			600.0)).is_true()
	assert_str(String(province.terrain_at(rock).id)).is_equal("stony")
	assert_object(scene).is_not_null()


func test_lake_counts_as_water_for_anglers_and_clay_pits() -> void:
	var sim := SimFixture.make_sim()
	var lake := SimFixture.registry().get_terrain(&"lake")
	for y: int in range(0, 32):
		for x: int in range(20, 32):
			sim.province.grid.set_terrain(Vector2i(x, y), lake.index)
	sim.province.rebuild_nav()
	var registry := SimFixture.registry()
	assert_str(String(sim.province.placement_error(registry.get_building(&"fishing_hut"), Vector2i(16, 10)))).is_empty()
	assert_str(String(sim.province.placement_error(registry.get_building(&"clay_pit"), Vector2i(16, 16)))).is_empty()
	assert_str(String(sim.province.placement_error(registry.get_building(&"fishing_hut"), Vector2i(2, 10)))) \
			.is_equal("no_water_nearby")
	var hut := SimFixture.place(sim, &"fishing_hut", Vector2i(16, 10))
	assert_bool(sim.province.find_shore(hut, hut.entrance_tile()) != Agent.NO_TILE).is_true()
	assert_bool(sim.province.nav.is_walkable(Vector2i(25, 10))).is_false()
