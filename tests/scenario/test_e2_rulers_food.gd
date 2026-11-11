extends GdUnitTestSuite
## E2 part 4: the AI rulers and the neutral settlements have an orchard with its apple trees
## and a hunter's lodge by the herds; a ruler short of food builds them first.


func _game() -> Simulation:
	var s := GameSettings.new()
	s.world_seed = 5
	s.rulers = 2
	s.province_count = 18
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1, problems)
	assert_array(Array(problems)).is_empty()
	return sim


func _first(town: ProvinceSim, id: StringName) -> BuildingState:
	for building: BuildingState in town.buildings.all():
		if building.def.id == id:
			return building
	return null


func test_ruler_capitals_start_with_an_orchard_and_its_trees() -> void:
	var sim := _game()
	for owner: StringName in Rulers.alive(sim.world):
		var town := sim.province_state(Rulers.provinces_of(sim.world, owner)[0])
		var orchard := _first(town, &"orchard")
		assert_object(orchard).override_failure_message("%s has no orchard" % owner).is_not_null()
		assert_int(int(town.fields.counts().get(orchard.id, 0))).is_equal(NeutralTown.FIELDS)


func test_neutral_settlements_have_an_orchard_and_a_hunter() -> void:
	var sim := _game()
	var neutral := 0
	for id: int in sim.world.provinces:
		if sim.world.owner_of(id) != ProvinceDef.OWNER_NEUTRAL:
			continue
		var town := sim.province_state(id)
		if town == null:
			continue
		neutral += 1
		assert_object(_first(town, &"orchard")).is_not_null()
		assert_object(_first(town, &"hunter_lodge")).is_not_null()
	assert_int(neutral).is_greater(0)


func test_a_lodge_goes_up_between_the_town_and_the_nearest_herd() -> void:
	var sim := _game()
	var town := sim.province_state(Rulers.provinces_of(sim.world, Rulers.alive(sim.world)[0])[0])
	sim.run_ticks(SimClock.TICKS_PER_SECOND * 2)
	var centre := RulerPlanner.centre(town)
	var herds := town.wild.all()
	assert_bool(herds.is_empty()).is_false()
	var nearest := herds[0].tile
	for herd: WildHerds.Herd in herds:
		if (herd.tile - centre).length_squared() < (nearest - centre).length_squared():
			nearest = herd.tile
	assert_that(NeutralTown.hunting_ground(town, centre)).is_equal((centre + nearest) / 2)


func test_a_ruler_short_of_food_builds_an_orchard_and_a_hunter_first() -> void:
	var sim := _game()
	sim.run_ticks(SimClock.TICKS_PER_SECOND * 2)
	var town := sim.province_state(Rulers.provinces_of(sim.world, Rulers.alive(sim.world)[0])[0])
	for good: StringName in [&"bread", &"fish", &"apples", &"meat"]:
		town.take_from_storages(good, town.stored(good), RulerPlanner.centre(town))
	assert_int(RulerPlanner.food(town)).is_less(RulerPlanner.LOW_FOOD)
	var counts := RulerPlanner.counts_of(town)
	counts.erase(&"orchard")
	counts.erase(&"hunter_lodge")
	assert_array(RulerPlanner.shortages(town, counts)).contains([&"orchard", &"hunter_lodge"])


func test_the_plan_has_orchards_and_a_hunter() -> void:
	var ids: Array[StringName] = []
	for entry: Array in RulerPlanner.PLAN:
		ids.append(entry[0])
	assert_array(ids).contains([&"orchard", &"hunter_lodge"])
