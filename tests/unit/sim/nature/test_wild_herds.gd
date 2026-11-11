extends GdUnitTestSuite
## E2 part 2: deer and boar herds live on the forest and meadows, wander, grow and flee.


func _forest_sim() -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var forest := SimFixture.registry().get_terrain(&"forest")
	for y: int in range(20, 38):
		for x: int in range(20, 38):
			sim.province.grid.set_terrain(Vector2i(x, y), forest.index)
	return sim


func test_herds_come_out_of_the_woods_and_wander() -> void:
	var sim := _forest_sim()
	sim.run_ticks(SimFixture.ticks(2))
	var wild := sim.province.wild
	assert_bool(wild.populated).is_true()
	assert_int(wild.herds.size()).is_equal(wild.target(sim.province))
	assert_int(wild.herds.size()).is_greater_equal(WildHerds.MIN_HERDS)
	var start: Dictionary = {}
	for herd: WildHerds.Herd in wild.all():
		assert_str(String(sim.province.terrain_at(herd.tile).id)).is_equal("forest")
		start[herd.id] = herd.tile
	sim.run_ticks(SimFixture.ticks(WildHerds.WANDER_SECONDS + WildHerds.WANDER_SPREAD + 2))
	var moved := 0
	for herd: WildHerds.Herd in wild.all():
		if herd.tile != start[herd.id]:
			moved += 1
		assert_bool(sim.province.is_tile_solid(herd.tile)).is_false()
	assert_int(moved).is_greater(0)


func test_no_herds_without_forest() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	sim.run_ticks(SimFixture.ticks(2))
	assert_int(sim.province.wild.herds.size()).is_equal(0)


func test_a_herd_grows_to_its_size_and_flees_from_a_shot() -> void:
	var sim := _forest_sim()
	sim.run_ticks(SimFixture.ticks(2))
	var wild := sim.province.wild
	var herd: WildHerds.Herd = wild.all()[0]
	var start := herd.count
	sim.run_ticks(SimFixture.ticks(WildHerds.BREED_SECONDS * 3 + 1))
	assert_int(herd.count).is_greater(start)
	assert_int(herd.count).is_less_equal(WildHerds.size_of(herd.kind))
	var before := herd.tile
	var from := herd.tile + Vector2i(-3, 0)
	wild.take_one(sim.province, herd, from)
	assert_int(herd.count).is_greater_equal(1)
	assert_int((herd.tile - before).x).is_greater(0)   # away from the hunter
	while wild.herds.has(herd.id):
		wild.take_one(sim.province, herd, from)
	assert_bool(wild.herds.has(herd.id)).is_false()


func test_herds_survive_a_save() -> void:
	var sim := _forest_sim()
	sim.run_ticks(SimFixture.ticks(2))
	var state := JSON.parse_string(JSON.stringify(sim.to_dict(), "", false, true)) as Dictionary
	var loaded := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(loaded.province.wild.animals()).is_equal(sim.province.wild.animals())
	assert_bool(loaded.province.wild.populated).is_true()
