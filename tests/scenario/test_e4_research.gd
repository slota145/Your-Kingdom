extends GdUnitTestSuite
## E4 part 2: the school and the kingdom's research (owner's surveys 2026-11-11). A school stands
## after the first burghers' house; its teacher at work moves the research on (gold paid at the
## start, a queue, two schools twice as fast); research unlocks buildings and ships and improves
## porters, fields, pens, the forester and the fishermen in every province of the player.


## A locked game (as one from "New game") with a stockpile full of materials and gold.
func _locked(size: Vector2i = Vector2i(40, 40)) -> Simulation:
	var sim := SimFixture.make_sim(size)
	sim.research = ResearchState.new()
	sim.bind_research()
	sim.treasury.gold = 5000
	return sim


## A burghers' house and a finished school with its teacher standing at it.
func _school(sim: Simulation, at: Vector2i = Vector2i(10, 10)) -> BuildingState:
	var house := SimFixture.house(sim, Vector2i(2, 2))
	house.house.level = 2
	var school := SimFixture.place(sim, &"school", at)
	var teacher := SimFixture.spawn(sim, &"teacher", school.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(teacher.id, school.id)))).is_empty()
	return school


func test_locked_buildings_and_the_school_from_the_start() -> void:
	var sim := _locked()
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"tailor", Vector2i(20, 20))))).is_equal("needs_research")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"weaver", Vector2i(20, 20))))).is_empty()
	# E4 part 5 (owner's survey 2026-11-12): the school from the start, no burghers needed.
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"school", Vector2i(26, 26))))).is_empty()
	# Research needs a finished school.
	assert_str(String(sim.execute(StartResearchCommand.new(&"tailoring")))).is_equal("needs_school")
	# An open game (tests, tools, the rulers) builds everything.
	var open := SimFixture.make_sim(Vector2i(40, 40))
	open.treasury.gold = 1000
	assert_str(String(open.execute(PlaceBuildingCommand.new(&"tailor", Vector2i(20, 20))))).is_empty()


func test_the_teacher_studies_and_the_research_unlocks() -> void:
	var sim := _locked()
	_school(sim)
	var gold := sim.treasury.gold
	assert_str(String(sim.execute(StartResearchCommand.new(&"butchery")))).is_empty()
	assert_str(String(sim.research.current)).is_equal("butchery")
	assert_int(sim.treasury.gold).is_equal(gold - sim.data.get_research(&"butchery").gold_cost)
	# Queued: the next starts when the first is done; one needing another waits behind it.
	assert_str(String(sim.execute(StartResearchCommand.new(&"larger_pens")))).is_empty()
	assert_str(String(sim.execute(StartResearchCommand.new(&"winemaking")))).is_equal("needs_research")
	assert_array(sim.research.queue).contains([&"larger_pens"])
	sim.run_ticks(SimFixture.ticks(5))
	assert_float(sim.research.progress).is_greater(0.0)
	var done := SimFixture.run_until(sim, func() -> bool: return sim.research.is_done(&"butchery"), 160)
	assert_bool(done).override_failure_message("butchery not researched").is_true()
	assert_str(String(sim.research.current)).is_equal("larger_pens")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"pigsty", Vector2i(24, 24))))).is_empty()


func test_no_teacher_no_progress_and_two_schools_twice_as_fast() -> void:
	var sim := _locked(Vector2i(48, 48))
	var school := _school(sim)
	sim.execute(StartResearchCommand.new(&"fishing"))
	assert_int(Researching.teachers(sim, ResearchDef.SCHOOL)).is_equal(1)
	school.paused = true
	sim.run_ticks(SimFixture.ticks(10))
	assert_float(sim.research.progress).is_equal(0.0)
	school.paused = false
	var second := SimFixture.place(sim, &"school", Vector2i(30, 30))
	var teacher := SimFixture.spawn(sim, &"teacher", second.entrance_tile())
	sim.execute(AssignWorkerCommand.new(teacher.id, second.id))
	assert_int(Researching.teachers(sim, ResearchDef.SCHOOL)).is_equal(2)
	sim.run_ticks(SimFixture.ticks(10))
	assert_float(sim.research.progress).is_greater_equal(18.0)


func test_cancel_gives_the_gold_back() -> void:
	var sim := _locked()
	_school(sim)
	var gold := sim.treasury.gold
	sim.execute(StartResearchCommand.new(&"beekeeping"))
	sim.execute(StartResearchCommand.new(&"winemaking"))
	assert_str(String(sim.execute(CancelResearchCommand.new(&"beekeeping")))).is_empty()
	assert_int(sim.treasury.gold).is_equal(gold)
	assert_str(String(sim.research.current)).is_empty()
	# Winemaking needed beekeeping: it left the queue too.
	assert_array(sim.research.queue).is_empty()
	# Not enough gold: nothing starts.
	sim.treasury.gold = 10
	assert_str(String(sim.execute(StartResearchCommand.new(&"beekeeping")))).is_equal("not_enough_gold")


func test_upgrades_improve_the_work() -> void:
	var sim := _locked()
	var data := sim.data
	var farm := SimFixture.place(sim, &"farm", Vector2i(20, 4))
	var forester := SimFixture.place(sim, &"forester", Vector2i(4, 20))
	var pigsty := SimFixture.place(sim, &"pigsty", Vector2i(30, 30))
	var province := sim.province
	assert_int(province.field_limit(farm)).is_equal(farm.def.max_fields)
	assert_int(province.work_radius(forester)).is_equal(forester.def.work_radius)
	assert_int(province.research.porter_load(data)).is_equal(1)
	for id: StringName in [&"larger_fields", &"larger_pens", &"forestry", &"better_carrying", &"fishing"]:
		sim.research.complete(id)
	assert_int(province.field_limit(farm)).is_equal(farm.def.max_fields + 4)
	assert_int(province.field_limit(pigsty)).is_equal(pigsty.def.max_pens + 2)
	assert_int(province.work_radius(forester)).is_equal(forester.def.work_radius + 2)
	assert_float(province.research.work_speed(data, &"forester")).is_equal_approx(1.25, 0.001)
	assert_float(province.research.work_speed(data, &"fishing_hut")).is_equal_approx(1.25, 0.001)
	assert_float(province.research.work_speed(data, &"farm")).is_equal(1.0)
	assert_int(province.research.porter_load(data)).is_equal(2)
	# A porter now takes two at once.
	var from := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	from.stock.add(&"wood", 10)
	var to := SimFixture.place(sim, &"stockpile", Vector2i(12, 4))
	SimFixture.spawn(sim, &"porter", Vector2i(8, 8))
	sim.execute(RequestTransportCommand.new(&"wood", 6, from.id, to.id))
	var two := SimFixture.run_until(sim, func() -> bool:
		for agent: Agent in province.agents.all():
			if agent.carry_amount == 2:
				return true
		return false, 30)
	assert_bool(two).override_failure_message("no porter carried two").is_true()


func test_the_rulers_and_the_dev_mode() -> void:
	var sim := _locked()
	# A province of no ruler nor player (the raiders' kind) builds everything, no improvement
	# (the rulers have their own research from E4 part 5, test_e4_world.gd).
	assert_bool(sim.research_of(9999).open).is_true()
	assert_int(sim.research_of(9999).porter_load(sim.data)).is_equal(1)
	sim.execute(SetDevModeCommand.new(true))
	assert_int(sim.research.done.size()).is_equal(sim.data.researches().size())
	sim.execute(SetDevModeCommand.new(false))
	assert_bool(sim.research.is_done(&"tailoring")).is_true()


func test_ships_need_shipbuilding() -> void:
	var sim := _locked(Vector2i(40, 40))
	var yard := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	assert_object(yard).is_not_null()
	assert_str(String(sim.research.needed_for_ship(sim.data, &"warship"))).is_equal("shipbuilding")
	assert_bool(sim.research.allows_ship(sim.data, &"cog")).is_true()
	assert_bool(sim.research.allows_ship(sim.data, &"fishing_boat")).is_true()


func test_saved_and_old_games_have_everything() -> void:
	var sim := _locked()
	_school(sim)
	sim.execute(StartResearchCommand.new(&"butchery"))
	sim.execute(StartResearchCommand.new(&"fishing"))
	sim.run_ticks(SimFixture.ticks(3))
	var state := sim.to_dict()
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	assert_str(String(copy.research.current)).is_equal("butchery")
	assert_bool(copy.province.research == copy.research).is_true()
	var migrated := SaveMigrations.migrate({"tick": 1}, 38)
	var old := ResearchState.from_dict(migrated["research"])
	for def: ResearchDef in sim.data.researches():
		assert_bool(old.is_done(def.id)).override_failure_message("old save lacks %s" % def.id).is_true()
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(39)
	# Every research is data: it unlocks real buildings and ships, needs real research.
	for def: ResearchDef in sim.data.researches():
		for b: StringName in def.buildings + def.affects:
			assert_object(sim.data.get_building(b)).override_failure_message("%s: %s" % [def.id, b]).is_not_null()
		for s: StringName in def.ships:
			assert_object(sim.data.get_ship(s)).is_not_null()
		for r: StringName in def.requires:
			assert_object(sim.data.get_research(r)).is_not_null()
