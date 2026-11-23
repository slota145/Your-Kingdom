extends GdUnitTestSuite
## UI-3 part 3 (owner 2026-11-23): more beds in the barracks and soldier quarters, 12 beds each
## for the soldiers of the nearest barracks; they sleep there and drill and enlist at the
## barracks. Quarters are built only while a barracks stands.


func _soldiers(sim: Simulation, barracks: BuildingState, unit_id: StringName, count: int) -> void:
	var unit := sim.data.get_unit(unit_id)
	for i: int in count:
		var agent := sim.province.spawn_agent(unit_id, barracks.entrance_tile())
		agent.home_id = barracks.id
		agent.combat = CombatState.new(unit.combat.hp)
		barracks.soldiers.append(agent.id)


func test_quarters_need_a_barracks() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var def := sim.data.get_building(&"soldier_quarters")
	assert_int(def.extra_beds).is_equal(12)
	assert_str(String(PlaceBuildingCommand.research_error(sim.province, def))).is_equal("needs_barracks")
	SimFixture.place(sim, &"barracks_small", Vector2i(10, 10))
	assert_str(String(PlaceBuildingCommand.research_error(sim.province, def))).is_equal("")
	assert_bool(RulerPlanner.PLAN.any(func(e: Array) -> bool: return e[0] == &"soldier_quarters")).is_true()


func test_quarters_add_beds_to_the_nearest_barracks() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var p := sim.province
	var near := SimFixture.place(sim, &"barracks_small", Vector2i(10, 10))
	var far := SimFixture.place(sim, &"barracks_small", Vector2i(38, 38))
	assert_int(Barracks.beds(p, near)).is_equal(16)
	var a := SimFixture.place(sim, &"soldier_quarters", Vector2i(14, 10))
	var b := SimFixture.place(sim, &"soldier_quarters", Vector2i(10, 14))
	assert_object(Barracks.home_barracks(p, a)).is_same(near)
	assert_int(Barracks.beds(p, near)).is_equal(16 + 24)
	assert_int(Barracks.beds(p, far)).is_equal(16)
	assert_array(Barracks.quarters_of(p, near)).contains_exactly([a, b])
	# Recruiting and armies coming home see the extra beds.
	_soldiers(sim, near, &"spearman", 16)
	assert_str(String(Barracks.recruit_error(p, near, sim.data.get_unit(&"spearman")))).is_not_equal("barracks_full")
	_soldiers(sim, near, &"spearman", 24)
	assert_str(String(Barracks.recruit_error(p, near, sim.data.get_unit(&"spearman")))).is_equal("barracks_full")
	assert_int(Barracks.free_beds(p, near)).is_equal(0)
	# Pulled down, the quarters leave the barracks overfull: nobody is thrown out.
	p.remove_building(b.id)
	assert_int(Barracks.beds(p, near)).is_equal(28)
	assert_int(Barracks.free_beds(p, near)).is_equal(0)
	assert_int(near.soldiers.size()).is_equal(40)


func test_soldiers_past_the_barracks_beds_sleep_in_the_quarters() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var p := sim.province
	var small := SimFixture.place(sim, &"barracks_small", Vector2i(14, 14))
	var quarters := SimFixture.place(sim, &"soldier_quarters", Vector2i(19, 14))
	_soldiers(sim, small, &"spearman", 20)
	assert_object(Barracks.rest_tile(p, small, 15)).is_equal(small.entrance_tile())
	assert_object(Barracks.rest_tile(p, small, 16)).is_equal(quarters.entrance_tile())
	sim.run_ticks(SimFixture.ticks(30))
	var at_quarters := 0
	for id: int in small.soldiers:
		var agent := p.agents.get_agent(id)
		if agent.tile() == quarters.entrance_tile():
			at_quarters += 1
		else:
			assert_object(agent.tile()).is_equal(small.entrance_tile())
	assert_int(at_quarters).is_equal(4)
	# The save keeps the same course.
	var copy := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict(), "", true, true)),
			SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
