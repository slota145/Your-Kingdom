extends GdUnitTestSuite
## E4 part 4: the small and large barracks (owner's surveys 2026-11-11). The small barracks (2x2,
## 10 beds, archers and spearmen, nobody drills) stand from the start; the large "castle" barracks
## (5x5, 30 beds, every unit, drill in the courtyard) after the university's "Large barracks". The
## old 3x3 barracks are no longer built; those standing work on.


func _locked(size: Vector2i = Vector2i(48, 48)) -> Simulation:
	var sim := SimFixture.make_sim(size)
	sim.research = ResearchState.new()
	sim.bind_research()
	sim.treasury.gold = 9000
	return sim


func _soldiers(sim: Simulation, barracks: BuildingState, unit_id: StringName, count: int) -> Array[Agent]:
	var unit := sim.data.get_unit(unit_id)
	var agents: Array[Agent] = []
	for i: int in count:
		var agent := sim.province.spawn_agent(unit_id, barracks.entrance_tile())
		agent.home_id = barracks.id
		agent.combat = CombatState.new(unit.combat.hp)
		barracks.soldiers.append(agent.id)
		agents.append(agent)
	return agents


func test_small_from_the_start_large_after_research_old_not_built() -> void:
	var sim := _locked()
	var province := sim.province
	assert_str(String(PlaceBuildingCommand.research_error(province, sim.data.get_building(&"barracks_small")))).is_empty()
	assert_str(String(PlaceBuildingCommand.research_error(province, sim.data.get_building(&"barracks")))).is_equal("retired")
	assert_str(String(PlaceBuildingCommand.research_error(province, sim.data.get_building(&"barracks_large")))).is_equal("needs_research")
	assert_str(String(province.research.needed_for_building(sim.data, &"barracks_large"))).is_equal("large_barracks")
	sim.research.complete(&"large_barracks")
	assert_str(String(PlaceBuildingCommand.research_error(province, sim.data.get_building(&"barracks_large")))).is_empty()
	# The AI (research open) may still build any of them.
	var open := SimFixture.make_sim(Vector2i(32, 32))
	assert_str(String(PlaceBuildingCommand.research_error(open.province, open.data.get_building(&"barracks")))).is_empty()
	# The research is the university's cheapest, with nothing before it.
	var def := sim.data.get_research(&"large_barracks")
	assert_str(String(def.institution)).is_equal("university")
	assert_int(def.tier).is_equal(1)
	assert_array(Array(def.requires)).is_empty()


func test_small_barracks_take_archers_and_spearmen_only() -> void:
	var sim := _locked()
	var small := SimFixture.place(sim, &"barracks_small", Vector2i(20, 20))
	var data := sim.data
	assert_int(small.def.soldier_beds).is_equal(10)
	sim.research.complete(&"armouring")
	sim.research.complete(&"chivalry")
	assert_str(String(Barracks.recruit_error(sim.province, small, data.get_unit(&"swordsman")))).is_equal("not_in_these_barracks")
	assert_str(String(Barracks.recruit_error(sim.province, small, data.get_unit(&"knight")))).is_equal("not_in_these_barracks")
	assert_str(String(Barracks.recruit_error(sim.province, small, data.get_unit(&"spearman")))).is_not_equal("not_in_these_barracks")
	assert_str(String(Barracks.recruit_error(sim.province, small, data.get_unit(&"archer")))).is_not_equal("not_in_these_barracks")
	var large := SimFixture.place(sim, &"barracks_large", Vector2i(30, 30))
	assert_int(large.def.soldier_beds).is_equal(30)
	assert_str(String(Barracks.recruit_error(sim.province, large, data.get_unit(&"knight")))).is_not_equal("not_in_these_barracks")
	assert_object(Barracks.with_bed_for(sim.province, &"knight")).is_same(large)


func test_small_barracks_soldiers_rest_inside() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var small := SimFixture.place(sim, &"barracks_small", Vector2i(14, 14))
	_soldiers(sim, small, &"spearman", 4)
	sim.run_ticks(SimFixture.ticks(20))
	for id: int in small.soldiers:
		var agent := sim.province.agents.get_agent(id)
		assert_bool(Barracks.post_of(sim.province, small, small.soldiers.find(id)).x < 0.0).is_true()
		assert_object(agent.tile()).is_equal(small.entrance_tile())
		assert_str(String(agent.activity)).is_equal("idle")


func test_large_barracks_drill_in_the_courtyard_and_march_out() -> void:
	for orientation: int in 2:
		var sim := SimFixture.make_sim(Vector2i(32, 32))
		var large := sim.province.add_building(sim.data.get_building(&"barracks_large"), Vector2i(12, 12), true,
				orientation)
		var court := Barracks.courtyard_tiles(large)
		assert_int(court.size()).is_equal(8)
		assert_bool(court.has(large.entrance_tile())).is_false()
		for tile: Vector2i in court:
			assert_int(sim.province.grid.occupant(tile)).is_equal(large.id)
		var men := _soldiers(sim, large, &"spearman", 20)
		sim.run_ticks(SimFixture.ticks(30))
		var places: Dictionary[Vector2, bool] = {}
		for k: int in men.size():
			var agent := men[k]
			var post := Barracks.post_of(sim.province, large, k)
			if k < 16:
				assert_float(agent.pos.distance_to(post)).override_failure_message(
						"soldier %d at %s, post %s (orientation %d)" % [k, agent.pos, post, orientation]).is_less(0.01)
				assert_bool(court.has(agent.tile())).override_failure_message("tile %s court %s post %s" % [agent.tile(), court, post]).is_true()
				places[post] = true
			else:
				assert_bool(post.x < 0.0).is_true()   # the rest rest inside
				assert_object(agent.tile()).is_equal(large.entrance_tile())
		assert_int(places.size()).is_equal(16)
		var seen_drill := false
		for i: int in SimFixture.ticks(Barracks.DRILL_ROUND):
			sim.step()
			sim.events.drain()
			if men[0].activity == &"drill":
				seen_drill = true
		assert_bool(seen_drill).is_true()
		# A soldier in the ranks finds his way out (through the gate) when sent somewhere.
		var path := sim.province.find_path(men[0].tile(), Vector2i(2, 2))
		assert_bool(path.is_empty()).is_false()
		assert_object(path[0]).is_equal(large.entrance_tile())
		# One leaves the barracks' list: the others close up, nobody gets stuck in the courtyard.
		large.soldiers.erase(men[0].id)
		sim.province.remove_agent(men[0])
		sim.run_ticks(SimFixture.ticks(20))
		for k: int in large.soldiers.size():
			var agent := sim.province.agents.get_agent(large.soldiers[k])
			var post := Barracks.post_of(sim.province, large, k)
			var at := post if post.x >= 0.0 else IsoMath.tile_center(large.entrance_tile())
			assert_float(agent.pos.distance_to(at)).is_less(0.01)


func test_a_returning_army_leaves_knights_out_of_small_barracks() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var small := SimFixture.place(sim, &"barracks_small", Vector2i(14, 14))
	assert_bool(small.def.houses_unit(&"knight")).is_false()
	assert_bool(small.def.houses_unit(&"archer")).is_true()
	assert_bool(sim.data.get_building(&"barracks").houses_unit(&"knight")).is_true()


func test_rulers_count_any_barracks_and_fall_back_to_small() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	SimFixture.place(sim, &"barracks", Vector2i(10, 10))
	var counts := RulerPlanner.counts_of(sim.province)
	assert_int(counts.get(RulerPlanner.LARGE_BARRACKS, 0)).is_equal(1)


func test_v40_saves_get_large_barracks() -> void:
	var all_done: Array = SaveMigrations.V39_RESEARCH + SaveMigrations.V40_RESEARCH
	var old_all := {"research": {"open": false, "done": all_done, "current": "", "progress": 0.0, "queue": []}}
	var everything := ResearchState.from_dict(SaveMigrations.migrate_v40_to_v41(old_all)["research"])
	for def: ResearchDef in SimFixture.registry().researches():
		assert_bool(everything.is_done(def.id)).override_failure_message("missing %s" % def.id).is_true()
	var started := {"research": {"open": false, "done": ["butchery"], "current": "", "progress": 0.0, "queue": []}}
	var some := ResearchState.from_dict(SaveMigrations.migrate_v40_to_v41(started)["research"])
	assert_bool(some.is_done(&"large_barracks")).is_false()
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(41)
