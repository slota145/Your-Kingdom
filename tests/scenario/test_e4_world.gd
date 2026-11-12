extends GdUnitTestSuite
## E4 part 5: the rest of the world keeps up (owner's surveys 2026-11-11). Each AI ruler has his
## own research: at the start what his towns have, then his schools and university study it in a
## fixed order by difficulty, paid with his gold when 150 stay in his treasury. His planner puts
## up a school and the university (one for the realm) without patricians, in
## a town of 80 people with a school; the small barracks where the barracks were, the large ones
## after "Large barracks". He recruits only the units his research allows. A neutral settlement
## knows what it has; the Invasion starts with the soldiers' research; old saves give the rulers
## everything (v42).


func _game(scenario: StringName = GameSettings.COLONIZATION, difficulty: int = GameSettings.NORMAL) -> Simulation:
	var s := GameSettings.new()
	s.scenario = scenario
	s.world_seed = 5
	s.rulers = 2
	s.province_count = 18
	s.difficulty = difficulty
	s.fit_scenario()
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1, problems)
	assert_array(Array(problems)).is_empty()
	return sim


func _capital(sim: Simulation, owner: StringName) -> int:
	return Rulers.provinces_of(sim.world, owner)[0]


func _first(town: ProvinceSim, id: StringName) -> BuildingState:
	for building: BuildingState in town.buildings.all():
		if building.def.id == id:
			return building
	return null


## A finished building of [param id] in the ruler's town (placed as his planner would, at once).
func _build(town: ProvinceSim, id: StringName) -> BuildingState:
	var have := _first(town, id)
	if have != null:
		return have
	var b := NeutralTown.place(town, SimFixture.registry().get_building(id), RulerPlanner.centre(town))
	assert_object(b).override_failure_message("no room for %s" % id).is_not_null()
	return b


func test_rulers_start_with_the_research_of_their_towns() -> void:
	var sim := _game()
	var data := sim.data
	for owner: StringName in Rulers.alive(sim.world):
		var ruler := sim.world.rulers[owner] as RulerState
		assert_bool(ruler.research.open).is_false()
		var town := sim.province_state(_capital(sim, owner))
		# His town is his research's: the same state, not the open one.
		assert_object(town.research).is_same(ruler.research)
		assert_object(sim.research_of_owner(owner)).is_same(ruler.research)
		# Nothing of his town is locked, nothing he does not have is studied.
		for building: BuildingState in town.buildings.all():
			assert_bool(ruler.research.allows_building(data, building.def.id)) \
					.override_failure_message("%s locked for %s" % [building.def.id, owner]).is_true()
		assert_bool(ruler.research.is_done(&"armouring")).is_false()
		assert_bool(ruler.research.allows_unit(data, &"swordsman")).is_false()
		assert_bool(ruler.research.allows_unit(data, &"spearman")).is_true()


func test_divided_capitals_have_their_large_barracks_studied() -> void:
	var divided := _game(GameSettings.DIVIDED)
	for owner: StringName in Rulers.alive(divided.world):
		var ruler := divided.world.rulers[owner] as RulerState
		assert_bool(ruler.research.is_done(&"large_barracks")).override_failure_message(String(owner)).is_true()


func test_what_stands_brings_the_research_it_needs() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	SimFixture.place(sim, &"siege_workshop", Vector2i(10, 10))
	SimFixture.place(sim, &"tailor", Vector2i(20, 10))
	var towns: Array[ProvinceSim] = [sim.province]
	var state := ResearchState.of_towns(sim.data, towns)
	assert_bool(state.open).is_false()
	assert_bool(state.is_done(&"siege_engines")).is_true()
	assert_bool(state.is_done(&"crossbows")).is_true()   # (the siege engines need it)
	assert_bool(state.is_done(&"tailoring")).is_true()
	assert_bool(state.is_done(&"beekeeping")).is_false()


func test_neutral_settlements_know_what_they_have() -> void:
	var sim := _game()
	var neutral := 0
	for id: int in sim.world.ids():
		if sim.world.owner_of(id) != ProvinceDef.OWNER_NEUTRAL or sim.province_state(id) == null:
			continue
		neutral += 1
		var research := sim.research_of(id)
		assert_bool(research.open).is_false()
		assert_object(sim.province_state(id).research).is_same(research)
		for building: BuildingState in sim.province_state(id).buildings.all():
			assert_bool(research.allows_building(sim.data, building.def.id)).is_true()
		assert_bool(research.is_done(&"charter")).is_false()
	assert_int(neutral).is_greater(0)


func test_a_ruler_studies_in_order_with_his_reserve_of_gold() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var ruler := sim.world.rulers[owner] as RulerState
	var town := sim.province_state(_capital(sim, owner))
	# Without a school there is nothing to study.
	assert_str(String(RulerResearch.next(sim, ruler))).is_empty()
	_build(town, &"school")
	assert_str(String(RulerResearch.next(sim, ruler))).is_equal("butchery")
	var cost := sim.data.get_research(&"butchery").gold_cost
	ruler.treasury.gold = cost + RulerResearch.RESERVE_GOLD - 1
	assert_str(String(RulerResearch.update_owner(sim, ruler))).is_empty()
	ruler.treasury.gold = cost + RulerResearch.RESERVE_GOLD
	assert_str(String(RulerResearch.update_owner(sim, ruler))).is_equal("butchery")
	assert_int(ruler.treasury.gold).is_equal(RulerResearch.RESERVE_GOLD)
	assert_str(String(ruler.research.current)).is_equal("butchery")
	# The player's research is not touched.
	assert_str(String(sim.research.current)).is_empty()
	# A university's research waits for the university; then the soldiers come first (normal).
	ruler.research.complete(&"tailoring")
	ruler.research.complete(&"butchery")
	assert_str(String(RulerResearch.next(sim, ruler))).is_equal("beekeeping")
	_build(town, &"university")
	assert_str(String(RulerResearch.next(sim, ruler))).is_equal("large_barracks")
	# On easy the economy comes first.
	assert_int(RulerResearch.ORDER[GameSettings.EASY].find(&"armouring")) \
			.is_greater(RulerResearch.ORDER[GameSettings.EASY].find(&"larger_fields"))
	assert_int(RulerResearch.ORDER[GameSettings.HARD].find(&"chivalry")) \
			.is_less(RulerResearch.ORDER[GameSettings.HARD].find(&"forestry"))


func test_ruler_research_ends_in_his_schools_not_the_players() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var ruler := sim.world.rulers[owner] as RulerState
	var id := _capital(sim, owner)
	var town := sim.province_state(id)
	var school := _build(town, &"school")
	var abstract := sim.runtimes[id] as ProvinceAbstract
	abstract.staff[school.id] = 1
	ruler.treasury.gold = 5000
	assert_bool(Researching.begin_for(sim, owner, ruler.research, ruler.treasury, &"butchery")).is_true()
	assert_float(Researching.study_rate(sim, ResearchDef.SCHOOL, owner)).is_equal(1.0)
	assert_float(Researching.study_rate(sim, ResearchDef.SCHOOL)).is_equal(0.0)   # the player has none
	var finished: Array[Dictionary] = []
	var time := sim.data.get_research(&"butchery").time
	for k: int in int(time) + 2:
		Researching.update(sim)
		for e: Dictionary in sim.events.drain():
			if String(e["type"]).contains("research_finished"):
				finished.append(e)
	assert_bool(ruler.research.is_done(&"butchery")).is_true()
	assert_int(finished.size()).is_equal(1)
	assert_str(String(finished[0]["type"])).is_equal("ruler_research_finished")
	assert_str(String(finished[0]["owner"])).is_equal(String(owner))
	assert_bool(sim.research.is_done(&"butchery")).is_false()


func test_planner_school_university_and_barracks() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var ruler := sim.world.rulers[owner] as RulerState
	var town := sim.province_state(_capital(sim, owner))
	var data := sim.data
	assert_bool(town.has_house_level(2)).is_true()   # (rulers' towns start with burghers)
	assert_bool(RulerPlanner._allowed(town, data.get_building(&"school"))).is_true()
	# The university: no patricians, but a school and 80 people.
	var university := data.get_building(&"university")
	assert_bool(town.has_house_level(3)).is_false()
	assert_bool(RulerPlanner._allowed(town, university)).is_false()
	_build(town, &"school")
	var people := RulerPlanner.residents(town)
	assert_bool(RulerPlanner._allowed(town, university)).is_equal(people >= RulerPlanner.UNIVERSITY_PEOPLE)
	for building: BuildingState in town.buildings.all():
		if building.house != null:
			building.house.residents = 10
	assert_int(RulerPlanner.residents(town)).is_greater_equal(RulerPlanner.UNIVERSITY_PEOPLE)
	assert_bool(RulerPlanner._allowed(town, university)).is_true()
	# Bricks are stone for him.
	var cost := RulerPlanner.cost_for_ruler(university)
	assert_bool(cost.has(&"bricks")).is_false()
	assert_int(cost[&"stone"]).is_equal(int(university.build_cost[&"stone"]) + int(university.build_cost[&"bricks"]))
	# Locked buildings wait for their research.
	assert_bool(RulerPlanner._allowed(town, data.get_building(&"barracks_large"))).is_false()
	assert_bool(RulerPlanner._allowed(town, data.get_building(&"apiary"))).is_false()
	ruler.research.complete(&"large_barracks")
	assert_bool(RulerPlanner._allowed(town, data.get_building(&"barracks_large"))).is_true()
	# The plan: the small barracks where the barracks were, the large ones after the university.
	var plan: Array[StringName] = []
	for entry: Array in RulerPlanner.PLAN:
		plan.append(entry[0])
	assert_int(plan.find(&"school")).is_greater(-1)
	assert_int(plan.find(&"barracks_small")).is_less(plan.find(&"university"))
	assert_int(plan.find(&"university")).is_less(plan.find(&"barracks_large"))


func test_rulers_university_site_asks_for_stone_not_bricks() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var ruler := sim.world.rulers[owner] as RulerState
	var id := _capital(sim, owner)
	var town := sim.province_state(id)
	var placed := RulerPlanner._open(sim, ruler, id, town, sim.data.get_building(&"university"))
	assert_object(placed).is_not_null()
	var site := town.sites.get(placed.site_id) as ConstructionSite
	var total := site.total_cost()
	assert_bool(total.has(&"bricks")).is_false()
	assert_int(int(total.get(&"stone", 0))).is_equal(28)


func test_counts_small_and_large_barracks() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	SimFixture.place(sim, &"barracks_small", Vector2i(10, 10))
	var counts := RulerPlanner.counts_of(sim.province)
	assert_int(counts.get(RulerPlanner.SMALL_BARRACKS, 0)).is_equal(1)
	assert_int(counts.get(RulerPlanner.LARGE_BARRACKS, 0)).is_equal(0)
	var big := SimFixture.make_sim(Vector2i(32, 32))
	SimFixture.place(big, &"barracks_large", Vector2i(10, 10))
	counts = RulerPlanner.counts_of(big.province)
	assert_int(counts.get(RulerPlanner.SMALL_BARRACKS, 0)).is_equal(1)
	assert_int(counts.get(RulerPlanner.LARGE_BARRACKS, 0)).is_equal(1)


func test_rulers_recruit_only_what_they_studied() -> void:
	var sim := _game(GameSettings.COLONIZATION, GameSettings.HARD)
	var owner: StringName = Rulers.alive(sim.world)[0]
	var ruler := sim.world.rulers[owner] as RulerState
	var id := _capital(sim, owner)
	var town := sim.province_state(id)
	_build(town, &"barracks_large")
	ruler.treasury.gold = 50000
	var units: Dictionary = {}
	for i: int in 14:
		var unit := RulerWar.recruit(sim, ruler, id)
		if unit != &"":
			units[unit] = true
	assert_bool(units.is_empty()).is_false()
	for unit: StringName in units:
		assert_bool(unit in [&"spearman", &"archer"]).override_failure_message(String(unit)).is_true()
	ruler.research.complete(&"armouring")
	var more: Dictionary = {}
	for i: int in 14:
		var unit := RulerWar.recruit(sim, ruler, id)
		if unit != &"":
			more[unit] = true
	assert_bool(more.has(&"swordsman") or more.has(&"halberdier") or more.has(&"man_at_arms")).is_true()


func test_the_invasion_starts_with_the_soldiers_research() -> void:
	var sim := _game(GameSettings.INVASION)
	for id: StringName in Invasion.START_RESEARCH:
		assert_bool(sim.research.is_done(id)).override_failure_message(String(id)).is_true()
	assert_bool(sim.research.is_done(&"chivalry")).is_false()
	var colony := _game()
	assert_bool(colony.research.is_done(&"armouring")).is_false()
	assert_bool(colony.research.open).is_false()


func test_ruler_research_is_saved_and_old_saves_get_everything() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var ruler := sim.world.rulers[owner] as RulerState
	ruler.research.complete(&"tailoring")
	ruler.research.current = &"butchery"
	ruler.research.progress = 33.0
	var copy := Simulation.from_dict(sim.to_dict(), sim.data)
	var loaded := copy.world.rulers[owner] as RulerState
	assert_bool(loaded.research.is_done(&"tailoring")).is_true()
	assert_str(String(loaded.research.current)).is_equal("butchery")
	assert_float(loaded.research.progress).is_equal(33.0)
	assert_object(copy.province_state(_capital(copy, owner)).research).is_same(loaded.research)
	# v41: the rulers had everything (research open for them): now all done.
	var old := sim.to_dict()
	for rd: Variant in (old["world"] as Dictionary)["rulers"]:
		(rd as Dictionary).erase("research")
	var migrated := SaveMigrations.migrate_v41_to_v42(old)
	var after := Simulation.from_dict(migrated, sim.data)
	for def: ResearchDef in sim.data.researches():
		assert_bool((after.world.rulers[owner] as RulerState).research.is_done(def.id)) \
				.override_failure_message("missing %s" % def.id).is_true()
	assert_int(SaveMigrations.CURRENT_VERSION).is_equal(42)


func test_the_automatic_player_studies() -> void:
	var sim := _game()
	var bot := AutoPlayer.new(sim)
	assert_bool(sim.research.open).is_false()
	assert_object(bot.state.research).is_same(sim.research)


func test_a_ruler_saves_for_his_university_but_not_for_ever() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var ruler := sim.world.rulers[owner] as RulerState
	var town := sim.province_state(_capital(sim, owner))
	_build(town, &"school")
	for building: BuildingState in town.buildings.all():
		if building.house != null:
			building.house.residents = 10
	assert_bool(RulerResearch.saving_for_university(sim, owner)).is_true()
	var cost := sim.data.get_research(&"butchery").gold_cost
	# Gold for the research only: it goes to the university.
	ruler.treasury.gold = cost + RulerResearch.RESERVE_GOLD
	assert_str(String(RulerResearch.update_owner(sim, ruler))).is_empty()
	# Gold for both (the university waits for room): he studies.
	ruler.treasury.gold = 500 + cost + RulerResearch.RESERVE_GOLD
	assert_str(String(RulerResearch.update_owner(sim, ruler))).is_equal("butchery")
	# With his university standing he saves for nothing.
	_build(town, &"university")
	assert_bool(RulerResearch.saving_for_university(sim, owner)).is_false()
