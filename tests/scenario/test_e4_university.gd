extends GdUnitTestSuite
## E4 part 3: the university (owner's survey 2026-11-11). It stands after the first patricians'
## house beside a school; two scholars study its research: armouring, crossbows, chivalry, siege
## engines, the large shipyard, carts, larger fields and pens II, the charter and deep learning.
## Stone walls, towers and gatehouses wait for the school's "Defensive masonry".


func _locked(size: Vector2i = Vector2i(48, 48)) -> Simulation:
	var sim := SimFixture.make_sim(size)
	sim.research = ResearchState.new()
	sim.bind_research()
	sim.treasury.gold = 9000
	return sim


func _staff(sim: Simulation, building: BuildingState, kind: StringName, count: int) -> void:
	for i: int in count:
		var agent := SimFixture.spawn(sim, kind, building.entrance_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(agent.id, building.id)))).is_empty()


func test_the_university_after_the_patricians_and_a_school() -> void:
	var sim := _locked()
	var house := SimFixture.house(sim, Vector2i(2, 2))
	house.house.level = 2
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"university", Vector2i(20, 20))))).is_equal("needs_patricians")
	house.house.level = 3
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"university", Vector2i(20, 20))))).is_equal("needs_school")
	SimFixture.place(sim, &"school", Vector2i(10, 10))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"university", Vector2i(20, 20))))).is_empty()


func test_two_scholars_study_the_university_research() -> void:
	var sim := _locked()
	var house := SimFixture.house(sim, Vector2i(2, 2))
	house.house.level = 3
	var school := SimFixture.place(sim, &"school", Vector2i(10, 10))
	_staff(sim, school, &"teacher", 1)
	assert_str(String(sim.execute(StartResearchCommand.new(&"crossbows")))).is_equal("needs_university")
	var uni := SimFixture.place(sim, &"university", Vector2i(20, 20))
	_staff(sim, uni, &"scholar", 2)
	assert_int(Researching.teachers(sim, ResearchDef.UNIVERSITY)).is_equal(2)
	assert_str(String(sim.execute(StartResearchCommand.new(&"crossbows")))).is_empty()
	sim.run_ticks(SimFixture.ticks(10))
	assert_float(sim.research.progress).is_greater_equal(18.0)
	var done := SimFixture.run_until(sim, func() -> bool: return sim.research.is_done(&"crossbows"), 200)
	assert_bool(done).override_failure_message("crossbows not researched").is_true()
	# Deep learning: the school teaches twice as fast.
	assert_float(Researching.study_rate(sim, ResearchDef.SCHOOL)).is_equal(1.0)
	sim.research.complete(&"deep_learning")
	assert_float(Researching.study_rate(sim, ResearchDef.SCHOOL)).is_equal(2.0)


func test_units_and_stone_walls_need_research() -> void:
	var sim := _locked()
	var barracks := SimFixture.place(sim, &"barracks", Vector2i(20, 20))
	var data := sim.data
	assert_str(String(Barracks.recruit_error(sim.province, barracks, data.get_unit(&"swordsman")))).is_equal("needs_research")
	assert_str(String(Barracks.recruit_error(sim.province, barracks, data.get_unit(&"knight")))).is_equal("needs_research")
	assert_str(String(Barracks.recruit_error(sim.province, barracks, data.get_unit(&"spearman")))).is_not_equal("needs_research")
	assert_str(String(Barracks.recruit_error(sim.province, barracks, data.get_unit(&"archer")))).is_not_equal("needs_research")
	sim.research.complete(&"armouring")
	assert_str(String(Barracks.recruit_error(sim.province, barracks, data.get_unit(&"swordsman")))).is_not_equal("needs_research")
	var line: Array[Vector2i] = [Vector2i(30, 30), Vector2i(31, 30), Vector2i(32, 30)]
	assert_str(String(sim.execute(BuildWallCommand.new(line, Walls.STONE)))).is_equal("needs_research")
	assert_str(String(sim.execute(BuildWallCommand.new(line, Walls.PALISADE)))).is_empty()
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"tower", Vector2i(36, 36))))).is_equal("needs_research")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"siege_workshop", Vector2i(36, 36))))).is_equal("needs_research")
	sim.research.complete(&"defensive_masonry")
	var stone: Array[Vector2i] = [Vector2i(30, 34), Vector2i(31, 34)]
	assert_str(String(sim.execute(BuildWallCommand.new(stone, Walls.STONE)))).is_empty()
	# The AI rulers' provinces recruit everything.
	assert_bool(sim.research_of(9999).allows_unit(data, &"knight")).is_true()
	assert_int(sim.research.cart_extra(data)).is_equal(0)
	sim.research.complete(&"carts")
	assert_int(sim.research.cart_extra(data)).is_equal(1)


func test_the_charter_doubles_the_fields_and_takes_a_second_worker() -> void:
	var sim := _locked()
	var farm := SimFixture.place(sim, &"farm", Vector2i(20, 20))
	var province := sim.province
	assert_bool(farm.can_have_charter()).is_true()
	assert_bool(SimFixture.place(sim, &"forester", Vector2i(4, 30)).can_have_charter()).is_false()
	assert_str(String(sim.execute(SetCharterCommand.new(farm.id, true)))).is_equal("needs_research")
	sim.research.complete(&"larger_fields")
	sim.research.complete(&"charter")
	assert_str(String(sim.execute(SetCharterCommand.new(farm.id, true)))).is_empty()
	assert_int(province.field_limit(farm)).is_equal((farm.def.max_fields + 4) * 2)
	assert_int(farm.worker_count()).is_equal(2)
	assert_int(farm.worker_kinds().size()).is_equal(2)
	_staff(sim, farm, &"farmer", 2)
	assert_int(farm.workers.size()).is_equal(2)
	# Both farmers work the fields together.
	SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	for x: int in range(16, 24):
		for y: int in [17, 18]:
			sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(x, y)))
	sim.run_ticks(SimFixture.ticks(90))
	var busy := 0
	for id: int in farm.workers:
		var agent := province.agents.get_agent(id)
		if agent != null and agent.task != null:
			busy += 1
	assert_int(busy).is_equal(2)
	assert_array(Array(province.dangling_holds())).is_empty()
	# Saved with the building.
	var copy := Simulation.from_dict(sim.to_dict(), SimFixture.registry())
	assert_bool(copy.province.buildings.get_building(farm.id).charter).is_true()
	# Taken back: one farmer again.
	assert_str(String(sim.execute(SetCharterCommand.new(farm.id, false)))).is_empty()
	assert_int(farm.worker_count()).is_equal(1)
	assert_int(province.field_limit(farm)).is_equal(farm.def.max_fields + 4)


func test_v39_saves_get_the_new_research() -> void:
	var old_all := {"research": {"open": false, "done": SaveMigrations.V39_RESEARCH.duplicate(), "current": "",
			"progress": 0.0, "queue": []}}
	var everything := ResearchState.from_dict(SaveMigrations.migrate_v39_to_v40(old_all)["research"])
	for def: ResearchDef in SimFixture.registry().researches():
		assert_bool(everything.is_done(def.id)).override_failure_message("missing %s" % def.id).is_true()
	var started := {"research": {"open": false, "done": ["butchery"], "current": "", "progress": 0.0, "queue": []}}
	var some := ResearchState.from_dict(SaveMigrations.migrate_v39_to_v40(started)["research"])
	assert_bool(some.is_done(&"defensive_masonry")).is_true()
	assert_bool(some.is_done(&"armouring")).is_false()
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(40)
