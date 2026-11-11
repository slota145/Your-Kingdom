extends GdUnitTestSuite
## Moved from test_m8_scenarios.gd (speed-up 2026-11-11).


func _settings(scenario: StringName, seed_value: int = 5, rulers: int = 2, count: int = 16) -> GameSettings:
	var s := GameSettings.new()
	s.scenario = scenario
	s.world_seed = seed_value
	s.rulers = rulers
	s.province_count = count
	s.fit_scenario()
	return s


# --- The Divided continent ---------------------------------------------------------------------

func test_divided_continent_starts_with_ready_towns() -> void:
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(SimFixture.registry(), _settings(GameSettings.DIVIDED, 5, 2, 12), 1, problems)
	assert_array(Array(problems)).is_empty()
	assert_object(sim.province.landing).is_not_null()
	for id: int in sim.world.ids():
		if id == sim.viewed_id:
			continue
		assert_bool(sim.runtimes.has(id)).override_failure_message("province %d has no town" % id).is_true()
	# A ruler's capital is bigger and has barracks (he recruits from the start).
	for owner: StringName in Rulers.alive(sim.world):
		var biggest := 0
		var barracks := false
		for id: int in Rulers.provinces_of(sim.world, owner):
			var town := sim.province_state(id)
			biggest = maxi(biggest, town.buildings.all().size())
			for b: BuildingState in town.buildings.all():
				barracks = barracks or b.def.soldier_beds > 0
		assert_int(biggest).is_greater(38)
		assert_bool(barracks).is_true()
		assert_int(Rulers.provinces_of(sim.world, owner).size()).is_greater_equal(2)


# --- The Merchant islands ------------------------------------------------------------------------

func test_gold_wins_the_merchant_islands_and_a_richer_ruler_wins_instead() -> void:
	var s := _settings(GameSettings.ISLANDS, 5, 2, 12)
	s.gold_target = 3000
	assert_str(String(s.victory)).is_equal(String(GameSettings.VICTORY_GOLD))
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1)
	sim.treasury.gold = 2999
	sim.run_ticks(SimFixture.ticks(2))
	assert_str(String(sim.world.result)).is_equal("")
	assert_array(Victory.progress(sim)).is_equal([2999, 3000])
	sim.treasury.gold = 3000
	sim.run_ticks(SimFixture.ticks(2))
	assert_str(String(sim.world.result)).is_equal(String(WorldSim.RESULT_WON))
	# A ruler first: the player loses, the ruler is named.
	var other := Simulation.from_settings(SimFixture.registry(), s, 1)
	other.world.rulers[&"ruler_2"].treasury.gold = 3000
	var lost := false
	for i: int in SimFixture.ticks(2):
		other.step()
		for e: Dictionary in other.events.drain():
			if e["type"] == &"game_lost":
				lost = String(e.get("winner", "")) == "ruler_2"
	assert_bool(lost).is_true()
